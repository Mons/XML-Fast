#ifndef _XML_FAST_H_
#define _XML_FAST_H_

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>


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
	void (*comment)(char *, unsigned int);
	void (*cdata)(char *, unsigned int);
	void (*text)(char *, unsigned int);
	void (*tagopen)(char *, unsigned int); //third is openstate. 0 - tag empty, 1 - tag have no attrs, 2 - tag may have attrs
	void (*attrname)(char *, unsigned int);
	void (*attrvalpart)(char *, unsigned int);
	void (*attrval)(char *, unsigned int);
	void (*tagclose)(char *, unsigned int);
} xml_callbacks;

struct entityref {
	char         c;
	char         *entity;
	unsigned int length;
	unsigned     children;
	struct       entityref *more;
};

#define mkents(er,N) \
do { \
	er->more = malloc( sizeof(struct entityref) * N ); \
	memset(er->more, 0, sizeof(struct entityref) * N); \
	er->children = N; \
} while (0)


#define BUFFER 4096
#define xml_error(x) do { printf("Error at char %d (%c): %s\n", p-xml, *p, x);goto fault; } while (0)

//Max string lengh for entity name, with trailing '\0'
#define MAX_ENTITY_LENGTH 5
#define MAX_ENTITY_VAULE_LENGTH 1
#define ENTITY_COUNT 5
static entity entitydef[] = {
	 { "lt",     "<"  }
	,{ "gt",     ">"  }
	,{ "amp",    "&"  }
	,{ "apos",   "'"  }
	,{ "quot",   "\"" }
};

extern void parse (char * xml, xml_callbacks * cb);

#endif
