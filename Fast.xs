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

void on_comment(char * data,unsigned int length) {
	SV *sv   = newSVpvn(data, length);
	SV **key = hv_fetch(NAMES, "comm", 4, 0);
	if (key && SvOK(*key)) {
		if (order) {
			HV *hv = newHV();
			SV *href = newRV_noinc( (SV *) hv );
			hv_store(collect, SvPV_nolen(*key), SvCUR(*key), sv, 0);
			av_push( ordered, href );
		} else {
			hv_store(collect, SvPV_nolen(*key), SvCUR(*key), sv, 0);
		}
	} else {
		printf("Ignore comment\n");
	}
}

void on_cdata(char * data,unsigned int length) {
	SV *sv   = newSVpvn(data, length);
	SV **key = hv_fetch(NAMES, "cdata", 5, 0);
	if (key && SvOK(*key)) {
		hv_store(collect, SvPV_nolen(*key), SvCUR(*key), sv, 0);
	} else {
		printf("Ignore CDATA\n");
	}
}

void on_text(char * data,unsigned int length) {
	SV *sv;
	SV **key = hv_fetch(NAMES, "text", 4, 0);
	SV **pval;
	if (key && SvOK(*key)) {
		pval = hv_fetch(collect, SvPV_nolen(*key), SvCUR(*key), 0);
		if (pval) {
			sv_catpvn(*pval, data,length);
		} else {
			sv = newSVpvn(data, length);
			hv_store(collect, SvPV_nolen(*key), SvCUR(*key), sv, 0);
		}
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
	SV **exists;
	if(!attrname) {
		croak("Got attrval without attrname\n");
	}
	if (attrval) {
		sv_catpvn(attrval, data, length);
	} else {
		attrval = newSVpvn(data, length);
	}
	char *key = SvPV_nolen(attrname);
	int len = SvCUR(attrname);
	if (exists = hv_fetch( collect, key, len, 0 )) {
		if (SvTYPE( SvRV(*exists) ) == SVt_PVAV) {
			// Already an array
			AV *av = (AV *) SvRV( *exists );
			av_push( av, attrval );
		} else {
			AV *ary  = newAV();
			SV *aref = newRV_noinc( (SV *) ary );
			SV *old  = newSV(0);
			sv_copypv(old,*exists);
			//printf("old val = %s\n",SvPV_nolen( old ));
			
			av_push( ary, old );
			av_push( ary, attrval );
			hv_store( collect, key, len, aref, 0 );
		}
	} else {
		hv_store(collect, key, len, attrval, 0);
	}
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
		if (order) {
			ordered = newAV();
			RETVAL = newRV_noinc( (SV *) ordered );
		} else{
			collect = newHV();
			RETVAL = newRV_noinc( (SV *) collect );
		}
		
		
		xml_callbacks cbs;
		memset(&cbs,0,sizeof(xml_callbacks));
		cbs.comment      = on_comment;
		cbs.cdata        = on_cdata;
		cbs.tagopen      = on_tag_open;
		cbs.tagclose     = on_tag_close;
		cbs.attrname     = on_attr_name;
		cbs.attrvalpart  = on_attr_val_part;
		cbs.attrval      = on_attr_val;
		cbs.text         = on_text;
		
		node_depth = -1;
		
		parse(xml,&cbs);
		
	OUTPUT:
		RETVAL

