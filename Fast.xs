#include "EXTERN.h"

//#define PERL_IN_HV_C
//#define PERL_HASH_INTERNAL_ACCESS

#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "xmlfast.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

HV * NAMES;
HV * collect;
AV * ordered;
//SV * nodename;

HV * node_chain[1024];
AV * node_ordered[1024];
int node_depth;

char order;

#define hv_store_a( hv, key, sv ) \
	STMT_START { \
		SV **exists; \
		char *kv = SvPV_nolen(key); \
		int   kl = SvCUR(key); \
		if( exists = hv_fetch(collect, kv, kl, 0) ) { \
			if (SvTYPE( SvRV(*exists) ) == SVt_PVAV) { \
				AV *av = (AV *) SvRV( *exists ); \
				av_push( av, sv ); \
			} else { \
				AV *av   = newAV(); \
				SV *old  = newSV(0); \
				sv_copypv(old,*exists); \
				av_push( av, old ); \
				av_push( av, sv ); \
				hv_store( collect, kv, kl, newRV_noinc( (SV *) av ), 0 ); \
			} \
		} else { \
			hv_store(collect, kv, kl, sv, 0); \
		} \
	} STMT_END

#define hv_store_cat( hv, key, data, length ) \
	STMT_START { \
		SV **exists; \
		char *kv = SvPV_nolen(key); \
		int   kl = SvCUR(key); \
		if( exists = hv_fetch(collect, kv, kl, 0) ) { \
			sv_catpvn(*exists, data,length);\
			\
		} else { \
			SV *sv = newSVpvn(data, length); \
			hv_store(collect, kv, kl, sv, 0); \
		} \
	} STMT_END

void on_comment(char * data,unsigned int length) {
	SV *sv   = newSVpvn(data, length);
	SV **key = hv_fetch(NAMES, "comm", 4, 0);
	SV **exists;
	if (key && SvOK(*key)) {
		hv_store_a(collect, *key, sv );
	} else {
		printf("Ignore Comment\n");
	}
}

void on_cdata(char * data,unsigned int length) {
	SV *sv   = newSVpvn(data, length);
	SV **key;
	if ((key = hv_fetch(NAMES, "cdata", 5, 0)) && SvOK(*key)) {
		//hv_store_cat(collect, *key, data, length);
		hv_store_a(collect, *key, sv );
	} else
	if ((key = hv_fetch(NAMES, "text", 4, 0)) && SvOK(*key)) {
		//hv_store_cat(collect, *key, data, length);
		hv_store_a(collect, *key, sv );
	} else
	{
		printf("Ignore CDATA\n");
	}
}

void on_wsp(char * data,unsigned int length) {
	SV *sv   = newSVpvn(data, length);
	//printf("Got WSP '%s'\n",SvPV_nolen(sv));
	SV **key = hv_fetch(NAMES, "text", 4, 0);
	SV **pval;
	if (key && SvOK(*key)) {
		//hv_store_cat(collect, *key, data, length);
		hv_store_a(collect, *key, sv );
	} else {
		printf("Ignore WSP\n");
	}
}

void on_text(char * data,unsigned int length) {
	SV *sv   = newSVpvn(data, length);
	//printf("Got text '%s'\n",SvPV_nolen(sv));
	SV **key = hv_fetch(NAMES, "text", 4, 0);
	SV **pval;
	if (key && SvOK(*key)) {
		//hv_store_cat(collect, *key, data, length);
		hv_store_a(collect, *key, sv );
	} else {
		printf("Ignore TEXT\n");
	}
}

void on_tag_open(char * data, unsigned int length) {
	SV *sv;
	if (order){
		AV * av = newAV();
		sv = newRV_noinc( (SV *) av );
		node_depth++;
		node_ordered[node_depth] = ordered;
		ordered = av;
	} else {
		HV * hv = newHV();
		sv = newRV_noinc( (SV *) hv );
		hv_store(collect, data, length, sv, 0);
		node_depth++;
		node_chain[node_depth] = collect;
		collect = hv;
	}
}

void on_tag_close(char * data, unsigned int length) {
	SV *sv   = newSVpvn(data, length);
	// TODO: check node name
	
	// Text joining
	SV **text;
	SV **key;
	if ((key = hv_fetch(NAMES, "text", 4, 0)) && SvOK(*key)) {
		if ((text = hv_fetch(collect, SvPV_nolen(*key), SvCUR(*key), 0)) && SvOK(*text)) {
			if (SvTYPE( SvRV(*text) ) == SVt_PVAV) {
				AV *av = (AV *) SvRV( *text );
				SV *svtext = newSV(0);
				SV **join;// = newSVpvn("+",1);
				SV **val;
				I32 len = 0, avlen = av_len(av);
				if ((join = hv_fetch(NAMES, "join", 4, 0)) && SvOK(*join)) {
					if (SvCUR(*join)) {
						//printf("Join length = %d\n",SvCUR(*join));
						for ( len = 0; len < avlen; len++ ) {
							if( ( val = av_fetch(av,len,0) ) && SvOK(*val) ) {
								if(len > 0) { sv_catsv(svtext,*join); }
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
					hv_store(collect, SvPV_nolen(*key), SvCUR(*key), svtext, 0);
				}
				else
				if ( avlen == 1 ) {
					val = av_fetch(av,0,0);
					if (val && SvOK(*val)) {
						sv_catsv(svtext,*val);
					}
					hv_store(collect, SvPV_nolen(*key), SvCUR(*key), svtext, 0);
				}
			}
			
		}
	}
	// Text joining
	
	if (node_depth > -1) {
		collect = node_chain[node_depth];
		node_depth--;
	} else {
		croak("Bad depth: %d for tag close %s\n",node_depth,SvPV_nolen(sv));
	}
}

SV *attrname;
SV *attrval;

void on_attr_name(char * data,unsigned int length) {
	if (attrname) {
		croak("Called attrname, while have attrname=%s\n",SvPV_nolen(attrname));
	}
	SV **key;
	if( key = hv_fetch(NAMES, "attr", 4, 0) ) {
		attrname = newSV(0);
		sv_copypv(attrname,*key);
		sv_catpvn(attrname, data, length);
	} else {
		attrname = newSVpvn(data, length);
	}
}

void on_attr_val_part(char * data,unsigned int length) {
	if(!attrname) {
		croak("Got attrval without attrname\n");
	}
	if (attrval) {
		sv_catpvn(attrval, data, length);
	} else {
		attrval = newSVpvn(data, length);
	}
}

void on_attr_val(char * data,unsigned int length) {
	if(!attrname) {
		croak("Got attrval without attrname\n");
	}
	if (attrval) {
		sv_catpvn(attrval, data, length);
	} else {
		attrval = newSVpvn(data, length);
	}
	hv_store_a(collect, attrname, attrval);
	attrname = 0;
	attrval = 0;
}

MODULE = XML::Fast		PACKAGE = XML::Fast

SV*
_xml2hash(xml,conf)
		char *xml;
		HV *conf;
	CODE:
		NAMES = conf;
		/*
		hv_store(NAMES, "order", 5, newSViv(0), 0 );
		hv_store(NAMES, "attr",  4, newSVpvn("-",1), 0 );
		hv_store(NAMES, "text",  4, newSVpvn("#text",5), 0 );
		hv_store(NAMES, "join",  4, newSVpvn("",0), 0 );
		hv_store(NAMES, "trim",  5, newSViv(1), 0 );
		hv_store(NAMES, "cdata", 5, newSVpvn("#",1), 0 );
		hv_store(NAMES, "comm",  4, newSVpvn("//",2), 0 );
		*/
		order = 0;//hv_fetch(NAMES,"order",5,0);
		xml_callbacks cbs;
		memset(&cbs,0,sizeof(xml_callbacks));
		if (order) {
			croak("Ordered mode not implemented yet\n");
		} else{
			collect = newHV();
			RETVAL = newRV_noinc( (SV *) collect );
			cbs.comment      = on_comment;
			cbs.cdata        = on_cdata;
			cbs.tagopen      = on_tag_open;
			cbs.tagclose     = on_tag_close;
			cbs.attrname     = on_attr_name;
			cbs.attrvalpart  = on_attr_val_part;
			cbs.attrval      = on_attr_val;
			cbs.text         = on_text;
			SV **trim;
			if ((trim = hv_fetch(NAMES, "trim", 4, 0)) && SvTRUE(*trim)) {
				printf("Have trim option\n");
			} else {
				printf("Have no trim option\n");
				cbs.wsp          = on_wsp;
			}
		}
		
		node_depth = -1;
		
		parse(xml,&cbs);
		
	OUTPUT:
		RETVAL

