#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
//#include "xmlfast.h"

#define PROCESSING_INSTRUCTION 0x0001
#define TEXT_NODE              0x0002

#define is_whitespace(p)       (*(p) == '\040' || *(p) == '\009' || *(p) == '\012' || *(p) == '\015')
//#define case_wsp               case '\040': case '\009' : case '\012' : case '\015'
#define case_wsp   \
		case 0x9  :\
		case 0xa  :\
		case 0xd  :\
		case 0x20

struct entityref {
	char c;
	char *entity;
	unsigned children;
	struct entityref *more;
};

#define mkents(er,N) \
do { \
	er->more = malloc( sizeof(struct entityref) * N ); \
	memset(er->more, 0, sizeof(struct entityref) * N); \
	er->children = N; \
} while (0)

static struct entityref entities;

//Max string lengh for entity name, with trailing '\0'
#define MAX_ENTITY_LENGTH 5
#define MAX_ENTITY_VAULE_LENGTH 1

struct entity {
	char * str;
	char * val;
};

#define ENTITY_COUNT 5

static struct entity entitydef[] = {
	 { "lt",     "<" }
	,{ "gt",     ">" }
	,{ "amp",    "&" }
	,{ "apos",   "'" }
	,{ "quot",   "\"" }
};

typedef struct {
	char *name;
	char *value;
} xml_attr;

typedef struct {
	char *name;
	char closed;
} xml_node;

void calculate(char *prefix, unsigned char offset, struct entity *strings, struct entityref *ents);
void calculate(char *prefix, unsigned char offset, struct entity *strings, struct entityref *ents) {
	unsigned char counts[256];
	unsigned char i,x,len;
	unsigned int total = 0;
	char pref[MAX_ENTITY_LENGTH];
	struct entityref *curent;
	struct entity *keep;
	memset(&counts,0,256);
	//printf("Counting, prefix='%s'\n",prefix);
	for (i = 0; i < ENTITY_COUNT; i++) {
		len = strlen(strings[i].str);
		if ( len > offset && strncmp( strings[i].str, prefix, offset ) == 0) {
			counts[ strings[i].str[offset] ]++;
		} else
		if ( len == offset ) {
			
		}
	}
	for (i = 0; i < 255; i++) {
		if (counts[i]) {
			total++;
			//printf("have %d children for '%c'\n",counts[i],i);
		}
	}
	strncpy(pref,prefix,offset+1);
	if (total == 0) {
		keep = 0;
		for (x = 0; x < ENTITY_COUNT; x++) {
			//printf("compare '%s'<=>'%s' (max %d)\n",strings[x].str, prefix, offset);
			if ( strncmp( strings[x].str, prefix, offset ) == 0) {
				keep = &(strings[x]);
				break;
			}
		}
		if (keep) {
			//printf("endpoint for c='%c': %s -> %s\n", ents->c ,prefix, keep->val);
			ents->entity = keep->val;
		} else {
			printf("fuck, not found keep");
		}
		return;
	}
	//printf("have totally %d strings, next prefix='%s'\n",total,pref);
	pref[offset+1] = '\0';
	mkents(ents,total);
	curent = ents->more;
	for (i = 0; i < 255; i++) {
		if (counts[i]) {
			curent->c = i;
			pref[offset] = i;
			calculate(pref,offset+1,strings,curent);
			++curent;
		}
	}
	return;
}

static void init_entities() {
	calculate("",0,entitydef,&entities);
	return;
/*
	static char *ents[5] = {
		"lt",
		"gt",
		"amp",
		"apos",
		"quot",
	};
	char counts[256], prefix[20];
	unsigned char i,x;
	for (x = 0; x < 4; x++) {
		memset(&counts,0,256);
		for (i = 0; i < 5; i++) {
			if (strlen(ents[i]) > x ) {
				counts[ ents[i][x] ]++;
			}
		}
		for (i = 0; i < 255; i++) {
			if (counts[i]) {
				printf("have %d children for '%c'\n",counts[i],i);
			}
		}
		printf("\n");
	}
	return;
	struct entityref *cur;
	mkents( (&entities), 4 );

	cur = entities.more;
	cur->c = 'l';
		mkents(cur,1);
		cur = cur->more; // [0]
		cur->c = 't';
		cur->entity = "<";

	cur = &( entities.more[1] );
	cur->c = 'g';
		mkents(cur,1);
		cur = cur->more;
		cur->c = 't';
		cur->entity = ">";

	cur = &( entities.more[2] );
	cur->c = 'q';
		mkents(cur,1);
		cur = cur->more;
		cur->c = 'u';
			mkents(cur,1);
			cur = cur->more;
			cur->c = 'o';
				mkents(cur,1);
				cur = cur->more;
				cur->c = 't';
				cur->entity = "\"";

	cur = &( entities.more[3] );
	cur->c = 'a';
		mkents(cur,2);
		cur = &( entities.more[3].more[0] );
		cur->c = 'm';
			mkents(cur,1);
			cur = cur->more;
			cur->c = 'p';
			cur->entity = "&";
		cur = &( entities.more[3].more[1] );
		cur->c = 'p';
			mkents(cur,1);
			cur = cur->more;
			cur->c = 'o';
				mkents(cur,1);
				cur = cur->more;
				cur->c = 's';
				cur->entity = "'";
	return;
*/
}

char * eat_wsp(char *p) {
	while (1) {
		switch (*p) {
			case_wsp :
				break;
			default:
				return p;
		}
		p++;
	}
}

char * eatback_wsp(char *p) {
	while (1) {
		p--;
		switch (*p) {
			case_wsp :
				break;
			default:
				return p;
		}
	}
}

char parse_entity (char **pp, char **pbuf) {
	char *p = *pp;
	char *buf = *pbuf;
						struct entityref *cur_ent, *last_ent;
						char *at;
						at = p;
						unsigned int i;
						cur_ent = &entities;
						next_ent:
						p++;
							if (*p == ';') {
								if (cur_ent && cur_ent->entity) {
									buf = strcpy(buf,cur_ent->entity) + 1;
									//printf("Entity terminated. result='%s', buffer='%s'\n",cur_ent->entity,buf-1);
									p++;
									goto ret;
								} else {
									//printf("Entity termination while not have cur\n");
									goto no_ent;
								}
							}
							for (i=0; i < cur_ent->children; i++) {
								//printf("\tcheck '%c' against '%c'\n", *p, cur_ent->more[i].c);
								if (cur_ent->more[i].c == *p) {
									cur_ent = &cur_ent->more[i];
									//printf("found ent ref '%c' (%s)\n",cur_ent->c, cur_ent->entity ? (cur_ent->entity) : " ");
									goto next_ent;
								}
							}
							if (cur_ent && cur_ent->entity) {
								//printf("Not found nested entity ref, but have good cur '%s'\n", cur_ent->entity);
								buf = strcpy(buf,cur_ent->entity) + 1;
								//p--;
								goto ret;
							} else {
								//printf("Not found entity ref\n");
							}
						no_ent:
						p = at;
						*pp = p;
						*pbuf = buf;
						return 0;
						
						ret:
						*pp = p;
						*pbuf = buf;
						
						return 1;
}

static void print_chain (xml_node *chain, int depth) {
	int i;
	xml_node * node;
	printf(":>> ");
	for (i=0; i < depth; i++) {
		node = &chain[i];
		printf("%s",node->name);
		if (i < depth-1 )printf(" > ");
	}
	printf("\n");
}

typedef struct {
	void (*comment)(char *, unsigned int);
	void (*cdata)(char *, unsigned int);
	void (*tagopen)(char *, unsigned int, unsigned char); //third is openstate. 0 - tag empty, 1 - tag have no attrs, 2 - tag may have attrs
	void (*attrname)(char *, unsigned int);
	void (*attrval)(char *, unsigned int);
} xml_callbacks;

#define BUFFER 4096
#define NODE_EMPTY     0
#define NODE_OPEN      1
#define NODE_OPENATTRS 2

#define xml_error(x) do { printf("Error at char %d (%c): %s\n", p-xml, *p, x);goto fault; } while (0)

static void parse (char * xml, xml_callbacks * cb) {
	if (!entities.more) {
		init_entities();
	}
	//return;
	char *p, *at, *end, *search, buffer[BUFFER], *buf, wait, loop;
	memset(&buffer,0,BUFFER);
	unsigned int state, len;
	p = xml;
	
	xml_node *chain, *root, *seek;
	int chain_depth = 16, curr_depth = 0;
	root = chain = malloc( sizeof(xml_node) * chain_depth );
	unsigned char node_closed;
	
	next:
	while (1) {
		if ( *p == '\0' ) break;
		//printf("%c\n",*p);
		switch(*p) {
			case '<':
				p++;
				//printf("node begin, next: %c\n",*p);
				switch (*p) {
					case '!':
						p++;
						if ( strncmp( p, "--", 2 ) == 0 ) {
							p+=2;
							search = strstr(p,"-->");
							if (search) {
								if (cb->comment) {
									cb->comment( p, search - p );
								} else {
									printf("No comment callback, ignored\n");
								}
								p = search + 3;
							} else xml_error("Comment node not terminated");
							goto next;
						} else
						if ( strncmp( p, "[CDATA[", 7 ) == 0) {
							p+=7;
							search = strstr(p,"]]>");
							if (search) {
								if (cb->cdata) {
									cb->cdata( p, search - p );
								} else {
									printf("No cdata callback, ignored\n");
								}
								p = search + 3;
							} else xml_error("Cdata node not terminated");
							goto next;
						} else
						{
							printf("fuckup after <!: %c\n",*p);
							goto fault;
						}
						break;
					case '?':
						search = strstr(p,"?>");
						if (search) {
							//printf("found pi node length = %d\n", search - p);
							snprintf( buffer, search - p + 1 - 1, "%s", p+1 );
							printf("PI: '%s'\n",buffer);
							p = search + 2;
							goto next;
						} else {
							printf ("PI node not terminated");
							goto fault;
						}
					case '/': // </node>
						search = index(p,'>');
						if (search) {
							//printf("found /tag node length = %d\n", search - p);
							len = search - p + 1 - 1;
							snprintf( buffer, len, "%s", p+1 );
							if (strncmp(chain->name, buffer, len) == 0) {
								printf("NODE/ CLOSE '%s'\n",buffer);
								if (curr_depth == 0) {
									printf("Need to close upper than root\n");
									goto fault;
								}
								curr_depth--;
								chain--;
								print_chain(root, curr_depth);
							} else {
								printf("NODE/ CLOSE '%s' (not current)\n",buffer);
								seek = chain;
								while( seek > root ) {
									seek--;
									//printf("cmp %s <> %s\n",chain)
									if (strncmp(seek->name, buffer, len) == 0) {
										printf("Found early opened node %s\n",seek->name);
										while(chain >= seek) {
											printf("Auto close %s\n",chain->name);
											chain--;
											curr_depth--;
											print_chain(root, curr_depth);
										}
										seek = 0;
									}
								}
								if (seek) {
									printf("Found no closing node until root for %s. open and close\n",buffer);
									print_chain(root, curr_depth);
								}
							}
							p = search;
							break;
						} else {
							printf ("close tag not terminated");
							goto fault;
						}
					default:
						buf = buffer;
						memset(&buffer,0,BUFFER);
						at = p;
						while(1) {
							switch(*p) {
								case 0: goto fault;
								case_wsp :
									if (buf > buffer) {
										*buf = 0;
										printf("NODE(... OPEN '%s'\n",buffer);
										
										curr_depth++;
										if (curr_depth != 1) chain++;
										chain->name = malloc( buf - buffer + 1 );
										strncpy(chain->name, buffer, buf - buffer + 1);
										print_chain(root, curr_depth);
										
										p = eat_wsp(p);
										if (*p == '>') {
											// pass to next
										} else {
											if (cb->tagopen) cb->tagopen( at, p - at, NODE_OPENATTRS );
											goto attrs;
										}
										
									} else {
										printf("Bad node opening\n");
										goto fault;
									}
								case '>' :
									if (buf > buffer) {
										*buf = 0;
										printf("NODE() OPEN '%s'\n",chain->name);
										search = eatback_wsp(p);
										if (*search == '/') {
											printf("\tIS SINGLE\n");
											node_closed = NODE_EMPTY;
										} else {
											node_closed = NODE_OPEN;
											curr_depth++;
											if (curr_depth != 1) chain++;
											chain->name = malloc( buf - buffer + 1 );
											strncpy(chain->name, buffer, buf - buffer + 1);
											print_chain(root, curr_depth);
										}
										if (cb->tagopen) cb->tagopen( at, p - at, node_closed );
										p++;
										goto next;
									} else {
										printf("Bad node opening\n");
										goto fault;
									}
								default:
									*buf = *p;
									//printf("node: %c (buf=%s)\n",*p,buffer);
									buf++;
							}
							p++;
						}
				}
				break;
			case_wsp :
				printf("skip \\%03o\n",*p);
				//p++;
				break;
			default:
				//printf("1st level: fuckup? '%c'\n",*p);
				//new
				buf = buffer;
				memset(&buffer,0,BUFFER);
				while (1) {
					switch(*p) {
						case '&':
							if( parse_entity(&p,&buf) )
								break;
						case '<':
							//printf("found text node length = %d, next='%c'\n", buf - buffer,p);
							//snprintf( buffer, search - p + 1, "%s", p );
							*buf = '\0';
							printf("TEXT='%s'\n",buffer);
							goto next;
						default:
							*(buf++) = *(p++);
						
					}
				}
				//new
				break;
				search = index(p,'<');
				if (search) {
					printf("found text node length = %d\n", search - p);
					snprintf( buffer, search - p + 1, "%s", p );
					printf("buffer='%s'\n",buffer);
				} else {
					if (*p == '\0') {
						printf ("End of document\n");
					} else {
						printf ("Text node not terminated. left '%s'\n",p);
						goto fault;
					}
				}
		}
		if ( *p == '\0' ) break;
		p++;
	}
	printf("parse done\n");
	return;
	
	int attrs;
	
	attrs:
		printf("Reading attrs for <%s>\n",chain->name);
		state = 0;
		/*
		 * state=0 - default, waiting for attr name or /?>
		 * state=1 - reading attr name
		 * state=2 - reading attr value
		 */
		buf = buffer;
		wait = '\0';
		loop = 1;
		p = eat_wsp(p);
		while(loop) {
			switch(state) {
				case 0: // waiting for attr name
					//printf("Want attr name, char='%c'\n",*p);
					while(state == 0) {
						switch(*p) {
							case_wsp :
								p = eat_wsp(p);
								break;
							case '>' :
								printf("\tno more\n");
								p++;
								goto next;
							case '?' :
							case '/' :
								at = p;
								p = eat_wsp(p+1); // +1 since current is / or ?
								if (*p == '>') {
									printf("Tag closed with %c\n",*at);
									p++;
									goto next;
								} else {
									printf("state=0 after / got='%c'\n",*p);
									goto fault;
								}
							default :
								//printf("state=0 default='%c'\n",*p);
								buf = buffer;
								state = 1;
								break;
						}
					}
					break;
				case 1: //reading attr name
					at = p;
					end = 0;
					while(state == 1) {
						switch(*p) {
							case_wsp :
								end = p;
								p = eat_wsp(p);
								//printf("state=1, eaten whitespace, p='%c'\n",*p);
								if (*p != '=') {
									printf("No = after whitespace while reading attr name\n");
									goto fault;
								}
							case '=':
								if (!end) end = p;
								if (cb->attrname) cb->attrname( at, end - at );
								*buf = '\0';
								//printf("End of attr name (%s)\n",buffer);
								printf("\tattr.name=<%s>\n",buffer);
								p++;
								p = eat_wsp(p);
								state = 2;
								break;
							default:
								*(buf++) = *(p++);
						}
					}
					break;
				case 2:
					wait = 0;
					char *valbuf, *valcopy;
					int  valsize, currsize;
					valsize = 2;
					currsize = 0;
					valcopy = valbuf = malloc(valsize + 1);
					while(state == 2) {
						switch(*p) {
							case '\'':
							case '"':
								if (!wait) { // got open quote
									//printf("\tgot open quote <%c>\n",*p);
									wait = *p;
									buf  = valbuf;
									p++;
									break;
								} else
								if (*p == wait) {  // got close quote
									//printf("\tgot close quote <%c>\n",*p);
									state = 0;
									*buf = '\0';
									p++;
									p = eat_wsp(p);
									printf("\tattr.value=<%s>, next='%c'\n",valbuf,*p);
									break;
								}
#define realloc_valbuf(buf,valbuf,valcopy,cursize,maxsize) \
										maxsize *= 2;\
										valcopy = valbuf;\
										valbuf  = malloc( maxsize + 1 );\
										memcpy(valbuf, valcopy, cursize);\
										valbuf[cursize] = 0;\
										buf = valbuf + cursize;\
										printf("realloc: %s | %s\n",valbuf,buf);\
										free(valcopy);
							case '&':
								if (wait) {
									//printf("Got entity begin (%s)\n",buffer);
									if (currsize + MAX_ENTITY_VAULE_LENGTH + 1 > valsize) {
										printf("Realloc for value(1) | %d => %d\n",valsize, valsize*2);
										realloc_valbuf(buf,valbuf,valcopy,currsize,valsize);
									}
									at = buf;
									if( parse_entity(&p,&buf) ) {
										currsize+= buf - at;
										break;
									}
								} else {
									printf("Not waiting for & in state 2\n");
									goto fault;
								}
							default:
								//printf("attr.val copy '%c'\n",*p);
								if (currsize + 2 > valsize) {
									realloc_valbuf(buf,valbuf,valcopy,currsize,valsize);
								}
								*(buf++) = *(p++);
								currsize++;
						}
					}
					break;
				default:
					printf("default, state=%d, char='%c'\n",state, *p);
					goto fault;
			}
		}
		goto next;
	
	fault:
	
	return;
}

void on_comment(char * data,unsigned int length) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("CB: <!-- '%s' -->\n",buffer);
	free(buffer);
}

void on_cdata(char * data,unsigned int length) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("CB: CDATA[ '%s' ]\n",buffer);
	free(buffer);
}

void on_tag_open(char * data, unsigned int length, unsigned char openstate) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("CB: +<%s%s>\n",buffer, openstate == NODE_EMPTY ? " /" : openstate == NODE_OPENATTRS ? "..." :  "");
	free(buffer);
}

void on_attr_name(char * data,unsigned int length) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("CB: ATTR '%s'=",buffer);
	free(buffer);
}

void on_attr_val(char * data,unsigned int length) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("'%s'\n",buffer);
	free(buffer);
}

int main () {
	//init_entities();
	//return 0;
	printf("ok\n");
	char *xml;
	xml =	"<?xml version=\"1.0\"?>"
			"<test>ok"
				"<test/> "
				"<test />\n"
				"<test></test>\t"
				"<!-- comment -->"
				"<![CDATA[d]]>"
				"<more abc = \"x>\" c='qwe\"qwe' d=\"qwe'qwe\" abcd=\"1&lt;&amp;&apos;&quot;&gt11&;22\" />"
				"</test>\n";
	xml = "<?xml version=\"1.0\"?><test1><test2><test3>ok<i>test<b>test</i>test</b></test3></test2></test1>";
	xml = "<?xml version=\"1.0\"?><test1 a='1&amp;234-5678-9012-3456-7890'><testi x='y' /><test2><test3><!-- comment --><![CDATA[cda]]>ok<i>test<b>test</i>test</b></test3></test2></test1> ";
	xml_callbacks cbs;
	memset(&cbs,0,sizeof(xml_callbacks));
	cbs.comment  = on_comment;
	cbs.cdata    = on_cdata;
	cbs.tagopen  = on_tag_open;
	cbs.attrname = on_attr_name;
	cbs.attrval  = on_attr_val;
	parse(xml,&cbs);
	return 0;
}

