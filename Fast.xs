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
	HV *hv;
	unsigned int keys;
} HVentry;

typedef struct {
	// config
	unsigned char order;
	unsigned char trim;
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
	HVentry ** hechain;
	HVentry  * hecurrent;
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
	//printf("Got text '%s'\n",SvPV_nolen(sv));
	hv_store_a(ctx->hcurrent, ctx->text, sv );
}

void on_tag_open(void * pctx, char * data, unsigned int length) {
	parsestate *ctx = pctx;
	SV *sv;
	HV * hv = newHV();
	sv = newRV_noinc( (SV *) hv );
	hv_store(ctx->hcurrent, data, length, sv, 0);
	ctx->depth++;
	if (ctx->depth >= ctx->chainsize) {
		Perl_warn(aTHX_ "XML depth too high. Consider increasing `_max_depth' to at more than %d to avoid reallocations",ctx->chainsize);
		HV ** keep = ctx->hchain;
		ctx->hchain = malloc( sizeof(ctx->hcurrent) * ctx->chainsize * 2);
		memcpy(ctx->hchain, keep, sizeof(ctx->hcurrent) * ctx->chainsize * 2);
		ctx->chainsize *= 2;
		free(keep);
	}

	ctx->hchain[ ctx->depth ] = ctx->hcurrent;
	//node_depth++;
	//node_chain[node_depth] = collect;
	ctx->hcurrent = hv;
}

void on_tag_close(void * pctx, char * data, unsigned int length) {
	parsestate *ctx = pctx;
	SV *sv   = newSVpvn(data, length);
	// TODO: check node name
	
	// Text joining
	SV **text;
	if (ctx->text) {
		//printf("Hash=%s\n",SvPV_nolen( hv_scalar(ctx->hcurrent) ));
		if ((text = hv_fetch(ctx->hcurrent, SvPV_nolen(ctx->text), SvCUR(ctx->text), 0)) && SvOK(*text)) {
			if (SvTYPE( SvRV(*text) ) == SVt_PVAV) {
				AV *av = (AV *) SvRV( *text );
				SV *svtext = newSV(0);
				SV **join;// = newSVpvn("+",1);
				SV **val;
				I32 len = 0, avlen = av_len(av);
				if (ctx->join) {
					if (SvCUR(ctx->join)) {
						//printf("Join length = %d\n",SvCUR(*join));
						for ( len = 0; len < avlen; len++ ) {
							if( ( val = av_fetch(av,len,0) ) && SvOK(*val) ) {
								if(len > 0) { sv_catsv(svtext,ctx->join); }
								sv_catsv(svtext,*val);
							}
						}
					} else {
						//printf("Optimized join loop\n");
						for ( len = 0; len < avlen; len++ ) {
							if( ( val = av_fetch(av,len,0) ) && SvOK(*val) ) {
								sv_catsv(svtext,*val);
							}
						}
					}
					//printf("Joined: %s\n",SvPV_nolen(svtext));
					hv_store(ctx->hcurrent, SvPV_nolen(ctx->text), SvCUR(ctx->text), svtext, 0);
				}
				else
				if ( avlen == 1 ) {
					val = av_fetch(av,0,0);
					if (val && SvOK(*val)) {
						sv_catsv(svtext,*val);
					}
					hv_store(ctx->hcurrent, SvPV_nolen(ctx->text), SvCUR(ctx->text), svtext, 0);
				}
			}
			
		}
	}
	// Text joining
	
	if (ctx->depth > -1) {
		ctx->hcurrent = ctx->hchain[ ctx->depth ];
		ctx->depth--;
		//collect = node_chain[node_depth];
		//node_depth--;
	} else {
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
	ctx->attrname = 0;
	ctx->attrval = 0;
}

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
			sv_copypv(ctx.attr = newSV(0),*key);
		}
		if ((key = hv_fetch(conf, "text", 4, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.text = newSV(0),*key);
		}
		if ((key = hv_fetch(conf, "join", 4, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.join = newSV(0),*key);
		}
		if ((key = hv_fetch(conf, "cdata", 5, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.cdata = newSV(0),*key);
		}
		if ((key = hv_fetch(conf, "comm", 4, 0)) && SvPOK(*key)) {
			sv_copypv(ctx.comm = newSV(0),*key);
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
		if (ctx.order) {
			croak("Ordered mode not implemented yet\n");
		} else{
			HVenrty c;
			ctx.hecurrent = c;
			ctx.hchain    = malloc( sizeof(ctx.hecurrent) * ctx.chainsize);
			
			ctx.hcurrent = newHV();
			ctx.hchain   = malloc( sizeof(ctx.hcurrent) * ctx.chainsize);
			ctx.depth    = -1;
			
			RETVAL  = newRV_noinc( (SV *) ctx.hcurrent );
			cbs.tagopen      = on_tag_open;
			cbs.tagclose     = on_tag_close;
			cbs.attrname     = on_attr_name;
			cbs.attrvalpart  = on_attr_val_part;
			cbs.attrval      = on_attr_val;
			
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
		
		free(ctx.hchain);
		
	OUTPUT:
		RETVAL

