#ifndef _XML_FAST_H_
#define _XML_FAST_H_

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>

#ifndef safemalloc
#define safemalloc malloc
#endif
#ifndef safefree
#define safefree free
#endif
#ifndef saferealloc
#define saferealloc realloc
#endif


#define PROCESSING_INSTRUCTION 0x0001
#define TEXT_NODE              0x0002

#define case_wsp   \
		case 0x9  :\
		case 0xa  :\
		case 0xd  :\
		case 0x20

typedef struct {
	char * str;
	char * val;
} entity;

typedef struct {
	char *name;
	char *value;
} xml_attr;

typedef struct {
	char *name;
	unsigned int len;
	char closed;
} xml_node;

typedef struct {
	void (*comment)(void *,char *, unsigned int);
	void (*cdata)(void *,char *, unsigned int);
	void (*text)(void *,char *, unsigned int);
	void (*tagopen)(void *,char *, unsigned int);
	void (*attrname)(void *,char *, unsigned int);
	void (*attrvalpart)(void *,char *, unsigned int);
	void (*attrval)(void *,char *, unsigned int);
	void (*tagclose)(void *,char *, unsigned int);
	void (*wsp)(void *,char *, unsigned int);
	void (*warn)(char *, ...);
	void (*die)(char *, ...);
} xml_callbacks;

struct entityref{
	char         c;
	char         *entity;
	unsigned int length;
	unsigned     children;
	struct entityref    *more;
};

// BUFFER used for some dummy copy operations. May be safely reduced to smaller numbers
#define BUFFER 4096
#define xml_error(x) do { printf("Error at char %d (%c): %s\n", p-xml, *p, x);goto fault; } while (0)

//Max string lengh for entity name, with trailing '\0'
#define MAX_ENTITY_LENGTH 5
#define ENTITY_COUNT 5
static entity entitydef[] = {
	 { "lt",     "<"  }
	,{ "gt",     ">"  }
	,{ "amp",    "&"  }
	,{ "apos",   "'"  }
	,{ "quot",   "\"" }
};

extern void parse (char * xml, void * ctx, xml_callbacks * cb);

#endif
