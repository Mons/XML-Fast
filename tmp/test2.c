#include "xmlfast.h"

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

void on_tag_open(char * data, unsigned int length) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("CB: +<%s>\n",buffer);
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

void on_attr_val_part(char * data,unsigned int length) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("'%s'",buffer);
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

void on_text(char * data,unsigned int length) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("CB: TEXT='%s'\n",buffer);
	free(buffer);
}

void on_tag_close(char * data, unsigned int length) {
	char * buffer;
	buffer = malloc(length+1);
	strncpy(buffer, data, length);
	*(buffer + length) = '\0';
	printf("CB: -</%s>\n",buffer);
	free(buffer);
}

int main () {
	//init_entities();
	//return 0;
	printf("ok\n");
	char *xml;
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
	xml =	"<?xml version=\"1.0\"?>"
			"<test>ok"
				"<test/> "
				"<test />\n"
				"<test></test>\t"
				"<!-- comment -->"
				"<![CDATA[d]]>"
				"<more abc = \"x>\" c='qwe\"qwe' d=\"qwe'qwe\" abcd=\"1&lt;&amp;&apos;&quot;&gt11&;22\" />"
				"</test>\n";
	//parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?><test1><test2><test3>ok<i>test<b>test</i>test</b></test3></test2></test1>";
	//parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?>"
			"<test1 a='1&amp;234-5678-9012-3456-7890'>"
				"<testi x='y' />"
				"<testz x='y' / >"
				"<test2>"
					"<test3>"
						"<!-- comment -->"
						"<![CDATA[cda]]>"
						"ok1&amp;ok2&gttest"
						"<i>test<b>test</i>test</b>"
					"</test3>"
				"</test2>"
			"</test1 > ";
	parse(xml,&cbs);
/*
	xml = "";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?>";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?><test";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?><test attr";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?><test attr=";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?><test attr='";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?><test attr='1'";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?><test attr='1'>";
	parse(xml,&cbs);
	xml = "<?xml version=\"1.0\"?><test attr='&g";
	parse(xml,&cbs);
	xml = "<test></test>";
	parse(xml,&cbs);
	xml = "<!";
	parse(xml,&cbs);
	xml = "<!--";
	parse(xml,&cbs);
	xml = "<![CDATA[";
	parse(xml,&cbs);
*/
	return 0;
}

