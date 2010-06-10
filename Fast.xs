#include "EXTERN.h"

#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "xmlfast.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

/*
commit 30866c9f74d890c45e8da27ea855468a314a59cf
xmlbare 1785/s      --    -19%
xmlfast 2209/s     24%      --

*/

typedef struct {
	// config
	unsigned int order;
	unsigned int trim;
	unsigned int bytes;
	SV  * attr;
	SV  * text;
	SV  * join;
	SV  * cdata;
	SV  * comm;

	// state
	char *encoding;
	SV   *encode;
	int depth;
	unsigned int chainsize;
	HV ** hchain;
	HV  * hcurrent;
	SV  * ctag;
	SV  * attrname;
	SV  * attrval;
	
} parsestate;


#define hv_store_a( hv, key, sv ) \
	STMT_START { \
		SV **exists; \
		char *kv = SvPV_nolen(key); \
		int   kl = SvCUR(key); \
		if( exists = hv_fetch(hv, kv, kl, 0) ) { \
			if (SvTYPE( SvRV(*exists) ) == SVt_PVAV) { \
				AV *av = (AV *) SvRV( *exists ); \
				/* printf("push '%s' to array in key '%s'\n", SvPV_nolen(old), kv); */ \
				av_push( av, sv ); \
			} \
			else if (SvTYPE( SvRV(*exists) ) == SVt_PVHV) { \
				AV *av   = newAV(); \
				SvREFCNT_inc(*exists); \
				av_push( av, *exists ); \
				av_push( av, sv ); \
				hv_store( hv, kv, kl, newRV_noinc( (SV *) av ), 0 ); \
			}\
			else { \
				AV *av   = newAV(); \
				SV *old  = newSV(0); \
				sv_copypv(old, *exists); \
				av_push( av, old ); \
				av_push( av, sv ); \
				hv_store( hv, kv, kl, newRV_noinc( (SV *) av ), 0 ); \
			} \
		} else { \
			hv_store(hv, kv, kl, sv, 0); \
		} \
	} STMT_END

#define hv_store_cat( hv, key, data, length ) \
	STMT_START { \
		SV **exists; \
		char *kv = SvPV_nolen(key); \
		int   kl = SvCUR(key); \
		if( exists = hv_fetch(hv, kv, kl, 0) ) { \
			sv_catpvn(*exists, data,length);\
		} else { \
			SV *sv = newSVpvn(data, length); \
			hv_store(hv, kv, kl, sv, 0); \
		} \
	} STMT_END

void on_comment(void * pctx, char * data,unsigned int length) {
	parsestate *ctx = pctx;
	SV         *sv  = newSVpvn(data, length);
	hv_store_a(ctx->hcurrent, ctx->comm, sv );
}

void on_cdata(void * pctx, char * data,unsigned int length) {
	parsestate *ctx = pctx;
	SV *sv   = newSVpvn(data, length);
	if (ctx->encode) {
		//printf("decode CDATA with %s\n",SvPV_nolen(ctx->encode));
		(void) sv_recode_to_utf8(sv, ctx->encode);
	}
	else if (!ctx->bytes) {
		SvUTF8_on(sv);
		//sv_utf8_decode(sv);
	}
	hv_store_a(ctx->hcurrent, ctx->cdata, sv );
}

void on_text(void * pctx, char * data,unsigned int length) {
	parsestate *ctx = pctx;
	SV *sv   = newSVpvn(data, length);
	//printf("Got text for '%s'\n",SvPV_nolen(sv));
	if (ctx->encode) {
		//printf("decode TEXT with %s\n",SvPV_nolen(ctx->encode));
		(void) sv_recode_to_utf8(sv, ctx->encode);
	}
	else if (!ctx->bytes) {
		SvUTF8_on(sv);
		//sv_utf8_decode(sv);
	}
	hv_store_a( ctx->hcurrent, ctx->text, sv );
}

void on_tag_open(void * pctx, char * data, unsigned int length) {
	parsestate *ctx = pctx;
	HV * hv = newHV();
	//SV *sv = newRV_noinc( (SV *) hv );
	//hv_store(ctx->hcurrent, data, length, sv, 0);
	ctx->depth++;
	if (ctx->depth >= ctx->chainsize) {
		Perl_warn("XML depth too high. Consider increasing `_max_depth' to at more than %d to avoid reallocations",ctx->chainsize);
		HV ** keep = ctx->hchain;
		ctx->hchain = safemalloc( sizeof(ctx->hcurrent) * ctx->chainsize * 2);
		memcpy(ctx->hchain, keep, sizeof(ctx->hcurrent) * ctx->chainsize * 2);
		ctx->chainsize *= 2;
		safefree(keep);
	}
	ctx->hchain[ ctx->depth ] = ctx->hcurrent;
	//node_depth++;
	//node_chain[node_depth] = collect;
	ctx->hcurrent = hv;
}

void on_tag_close(void * pctx, char * data, unsigned int length) {
	parsestate *ctx = pctx;
	// TODO: check node name
	
	// Text joining
	SV **text;
	I32 keys = HvKEYS(ctx->hcurrent);
	SV  *svtext = 0;
	if (ctx->text) {
		// we may have stored text node
		if ((text = hv_fetch(ctx->hcurrent, SvPV_nolen(ctx->text), SvCUR(ctx->text), 0)) && SvOK(*text)) {
			if (SvTYPE( SvRV(*text) ) == SVt_PVAV) {
				AV *av = (AV *) SvRV( *text );
				SV **val;
				I32 len = 0, avlen = av_len(av) + 1;
				if (ctx->join) {
					svtext = newSVpvn("",0);
					if (SvCUR(ctx->join)) {
						//printf("Join length = %d, avlen=%d\n",SvCUR(*join),avlen);
						for ( len = 0; len < avlen; len++ ) {
							if( ( val = av_fetch(av,len,0) ) && SvOK(*val) ) {
								//printf("Join %s with '%s'\n",SvPV_nolen(*val), SvPV_nolen(ctx->join));
								if(len > 0) { sv_catsv(svtext,ctx->join); }
								//printf("Join %s with '%s'\n",SvPV_nolen(*val), SvPV_nolen(ctx->join));
								sv_catsv(svtext,*val);
							}
						}
					} else {
						//printf("Optimized join loop\n");
						for ( len = 0; len < avlen; len++ ) {
							if( ( val = av_fetch(av,len,0) ) && SvOK(*val) ) {
								//printf("Join %s with ''\n",SvPV_nolen(*val));
								sv_catsv(svtext,*val);
							}
						}
					}
					//printf("Joined: to %s => '%s'\n",SvPV_nolen(ctx->text),SvPV_nolen(svtext));
					SvREFCNT_inc(svtext);
					hv_store(ctx->hcurrent, SvPV_nolen(ctx->text), SvCUR(ctx->text), svtext, 0);
				}
				else
				// currently unreachable, since if we have single element, it is stored as SV value, not AV
				//if ( avlen == 1 ) {
				//	Perl_warn("# AVlen=1\n");
				//	/* works
				//	svtext = newSVpvn("",0);
				//	val = av_fetch(av,0,0);
				//	if (val && SvOK(*val)) {
				//		//svtext = *val;
				//		//SvREFCNT_inc(svtext);
				//		sv_catsv(svtext,*val);
				//	}
				//	*/
				//	val = av_fetch(av,0,0);
				//	if (val) {
				//		svtext = *val;
				//		SvREFCNT_inc(svtext);
				//		hv_store(ctx->hcurrent, SvPV_nolen(ctx->text), SvCUR(ctx->text), svtext, 0);
				//	}
				//}
				//else
				{
					// Remebmer for use if it is single
					Perl_warn("# No join\n");
					svtext = newRV( (SV *) av );
				}
			} else {
				svtext = *text;
				SvREFCNT_inc(svtext);
			}
		}
	}
	//printf("svtext=(0x%lx) '%s'\n", svtext, svtext ? SvPV_nolen(svtext) : "");
	// Text joining
	SV *tag = newSVpvn(data,length);
	sv_2mortal(tag);
	if (ctx->depth > -1) {
		HV *hv = ctx->hcurrent;
		ctx->hcurrent = ctx->hchain[ ctx->depth ];
		ctx->hchain[ ctx->depth ];// = (HV *)NULL;
		ctx->depth--;
		if (keys == 1 && svtext) {
			//SV *sx   = newSVpvn(data, length);sv_2mortal(sx);
			//printf("Hash in tag '%s' for destruction have refcnt = %d (%lx | %lx)\n",SvPV_nolen(sx),SvREFCNT(hv), hv, ctx->hcurrent);
			SvREFCNT_inc(svtext);
			SvREFCNT_dec(hv);
			//hv_store(ctx->hcurrent, data, length, svtext, 0);
			hv_store_a(ctx->hcurrent, tag, svtext);
		} else {
			SV *sv = newRV_noinc( (SV *) hv );
			//printf("Store hash into RV '%lx'\n",sv);
			//hv_store(ctx->hcurrent, data, length, sv, 0);
			hv_store_a(ctx->hcurrent, tag, sv);
		}
		if (svtext) SvREFCNT_dec(svtext);
	} else {
		SV *sv   = newSVpvn(data, length);
		croak("Bad depth: %d for tag close %s\n",ctx->depth,SvPV_nolen(sv));
	}
}

void on_attr_name(void * pctx, char * data,unsigned int length) {
	parsestate *ctx = pctx;
	if (ctx->attrname) {
		croak("Called attrname, while have attrname=%s\n",SvPV_nolen(ctx->attrname));
	}
	SV **key;
	if( ctx->attr ) {
		/*
		Refactor
		*/
		ctx->attrname = newSV(0);
		sv_copypv(ctx->attrname,ctx->attr);
		sv_catpvn(ctx->attrname, data, length);
		//ctx->attrname = newSVpnv(ctx->attrv,ctx->attrl);
	} else {
		ctx->attrname = newSVpvn(data, length);
	}
}

void on_attr_val_part(void * pctx, char * data,unsigned int length) {
	parsestate *ctx = pctx;
	if(!ctx->attrname) {
		croak("Got attrval without attrname\n");
	}
	if (ctx->attrval) {
		sv_catpvn(ctx->attrval, data, length);
	} else {
		ctx->attrval = newSVpvn(data, length);
	}
}

void on_attr_val(void * pctx, char * data,unsigned int length) {
	parsestate *ctx = pctx;
	if(!ctx->attrname) {
		croak("Got attrval without attrname\n");
	}
	if (ctx->attrval) {
		sv_catpvn(ctx->attrval, data, length);
	} else {
		ctx->attrval = newSVpvn(data, length);
	}
	hv_store_a(ctx->hcurrent, ctx->attrname, ctx->attrval);
	sv_2mortal(ctx->attrname);
	//sv_2mortal(ctx->attrval);
	ctx->attrname = 0;
	ctx->attrval = 0;
}

void on_warn(char * format, ...) {
	/*
		my_vsnprintf
		The C library vsnprintf if available and standards-compliant.
		However, if if the vsnprintf is not available, will unfortunately use the unsafe
		vsprintf which can overrun the buffer (there is an overrun check, but that may
		be too late). Consider using sv_vcatpvf instead, or getting vsnprintf.
	*/
	va_list va;
	va_start(va,format);
	char buffer[1024];
	// TODO (segfault)
	vsnprintf(buffer,1023,format,va);
	Perl_warn(aTHX_ "%s",buffer);
	va_end(va);
}

SV * find_encoding(char * encoding) {
	dSP;
	int count;
	//require_pv("Encode.pm");
	
	ENTER;
	SAVETMPS;
	//printf("searching encoding '%s'\n",encoding);
	
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVpv(encoding, 0)));
	PUTBACK;
	
	count = call_pv("Encode::find_encoding",G_SCALAR);
	
	SPAGAIN;
	if (SvTRUE(ERRSV)) {
		printf("Shit happens: %s\n", SvPV_nolen(ERRSV));
		POPs;
	}
	
	if (count != 1)
		croak("Bad number of returned values: %d",count);
	
	SV *encode = POPs;
	//sv_dump(encode);
	SvREFCNT_inc(encode);
	//printf("Got encode=%s for encoding='%s'\n",SvPV_nolen(encode),encoding);
	
	PUTBACK;
	
	FREETMPS;
	LEAVE;
	
	return encode;
}

/*
#define newRVHV() newRV_noinc((SV *)newHV())
#define rv_hv_store(rv,key,len,sv,f) hv_store((HV*)SvRV(rv), key,len,sv,f)
#define rv_hv_fetch(rv,key,len,f) hv_fetch((HV*)SvRV(rv), key,len,f)
*/
/*
void
_test()
	CODE:
		SV *sv1 = newRVHV();
		SV *sv2 = newRVHV();
		sv_2mortal(sv1);
		sv_2mortal(sv2);
		SV *test = newSVpvn("test",4);
		rv_hv_store(sv1, "test",4,test,0);
		SvREFCNT_inc(test);
		rv_hv_store(sv2, "test",4,test,0);
*/

MODULE = XML::Fast		PACKAGE = XML::Fast

SV*
_xml2hash(xml,conf)
		char *xml;
		HV *conf;
	CODE:
		
		parsestate ctx;
		memset(&ctx,0,sizeof(parsestate));
		SV **key;
		if ((key = hv_fetch(conf, "order", 5, 0)) && SvTRUE(*key)) {
			ctx.order = 1;
		}
		if ((key = hv_fetch(conf, "trim", 4, 0)) && SvTRUE(*key)) {
			ctx.trim = 1;
		}
		if ((key = hv_fetch(conf, "bytes", 5, 0)) && SvTRUE(*key)) {
			ctx.bytes = 1;
		}
		if ((key = hv_fetch(conf, "trim", 4, 0)) && SvTRUE(*key)) {
			ctx.trim = 1;
		}
		if ((key = hv_fetch(conf, "attr", 4, 0)) && SvPOK(*key)) {
			ctx.attr = *key;
		}
		if ((key = hv_fetch(conf, "text", 4, 0)) && SvPOK(*key)) {
			ctx.text = *key;
		}
		if ((key = hv_fetch(conf, "join", 4, 0)) && SvPOK(*key)) {
			ctx.join = *key;
		}
		if ((key = hv_fetch(conf, "cdata", 5, 0)) && SvPOK(*key)) {
			ctx.cdata = *key;
		}
		if ((key = hv_fetch(conf, "comm", 4, 0)) && SvPOK(*key)) {
			ctx.comm = *key;
		}
		
		if ((key = hv_fetch(conf, "_max_depth", 10, 0)) && SvOK(*key)) {
			ctx.chainsize = SvIV(*key);
			if (ctx.chainsize < 1) {
				croak("_max_depth contains bad value (%d)",ctx.chainsize);
			}
		} else {
			ctx.chainsize = 256;
		}
		
		
		xml_callbacks cbs;
		memset(&cbs,0,sizeof(xml_callbacks));
		if (!ctx.bytes) {
			//if (utf8) {
				ctx.encoding = "utf8";
			//} else {
			//	ctx.encoding = "utf-8";
			//	ctx.encode = find_encoding(ctx.encoding);
			//}
		}
		
		if (ctx.order) {
			croak("Ordered mode not implemented yet\n");
		} else{
			ctx.hcurrent = newHV();
			
			ctx.hchain = safemalloc( sizeof(ctx.hcurrent) * ctx.chainsize);
			ctx.depth = -1;
			
			RETVAL  = newRV_noinc( (SV *) ctx.hcurrent );
			cbs.tagopen      = on_tag_open;
			cbs.tagclose     = on_tag_close;
			cbs.attrname     = on_attr_name;
			cbs.attrvalpart  = on_attr_val_part;
			cbs.attrval      = on_attr_val;
			cbs.warn         = on_warn;
			
			if(ctx.comm)
				cbs.comment      = on_comment;
			
			if(ctx.cdata)
				cbs.cdata        = on_cdata;
			else if(ctx.text)
				cbs.cdata        = on_text;
			
			if(ctx.text)
				cbs.text         = on_text;
			
			if (!ctx.trim)
				cbs.wsp          = on_text;
		}
		parse(xml,&ctx,&cbs);
		if(ctx.encode) SvREFCNT_dec(ctx.encode);
		safefree(ctx.hchain);
	OUTPUT:
		RETVAL

