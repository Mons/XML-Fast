#include "EXTERN.h"

#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "xmlfast.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

typedef struct {
	// config
	unsigned int order;
	unsigned int trim;
	SV  * attr;
	SV  * text;
	SV  * join;
	SV  * cdata;
	SV  * comm;

	// state
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
			} else { \
				AV *av   = newAV(); \
				SV *old  = newSV(0); \
				sv_copypv(old,*exists); \
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
			\
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
	hv_store_a(ctx->hcurrent, ctx->cdata, sv );
}

void on_text(void * pctx, char * data,unsigned int length) {
	parsestate *ctx = pctx;
	SV *sv   = newSVpvn(data, length);
	//printf("Got text for '%s'\n",SvPV_nolen(sv));
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
		
		//unsigned char count;
		//hv_iterinit(ctx->hcurrent);
		
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
				if ( avlen == 1 ) {
					svtext = newSVpvn("",0);
					val = av_fetch(av,0,0);
					if (val && SvOK(*val)) {
						//svtext = *val;
						//SvREFCNT_inc(svtext);
						sv_catsv(svtext,*val);
					}
					SvREFCNT_inc(svtext);
					hv_store(ctx->hcurrent, SvPV_nolen(ctx->text), SvCUR(ctx->text), svtext, 0);
				}
				else
				{
					// Remebmer for use if it is single
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
	if (ctx->depth > -1) {
		HV *hv = ctx->hcurrent;
		ctx->hcurrent = ctx->hchain[ ctx->depth ];
		ctx->hchain[ ctx->depth ];// = (HV *)NULL;
		ctx->depth--;
		if (keys == 1 && svtext) {
			//SV *sx   = newSVpvn(data, length);sv_2mortal(sx);
			//printf("Hash in tag '%s' for destruction have refcnt = %d (%lx | %lx)\n",SvPV_nolen(sx),SvREFCNT(hv), hv, ctx->hcurrent);
			SvREFCNT_dec(hv);
			SvREFCNT_inc(svtext);
			hv_store(ctx->hcurrent, data, length, svtext, 0);
		} else {
			SV *sv = newRV_noinc( (SV *) hv );
			//printf("Store hash into RV '%lx'\n",sv);
			hv_store(ctx->hcurrent, data, length, sv, 0);
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
		ctx->attrname = newSV(0);
		sv_copypv(ctx->attrname,ctx->attr);
		sv_catpvn(ctx->attrname, data, length);
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
		if ((key = hv_fetch(conf, "trim", 4, 0)) && SvTRUE(*key)) {
			ctx.trim = 1;
		}
		if ((key = hv_fetch(conf, "attr", 4, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.attr = sv_newmortal(),*key);
		}
		if ((key = hv_fetch(conf, "text", 4, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.text = sv_newmortal(),*key);
		}
		if ((key = hv_fetch(conf, "join", 4, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.join = sv_newmortal(),*key);
		}
		if ((key = hv_fetch(conf, "cdata", 5, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.cdata = sv_newmortal(),*key);
		}
		if ((key = hv_fetch(conf, "comm", 4, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.comm = sv_newmortal(),*key);
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
		//ctx.trash = newRV_noinc( (SV *)newAV() );
		//sv_2mortal(ctx.trash);
		
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
		safefree(ctx.hchain);
	OUTPUT:
		RETVAL

