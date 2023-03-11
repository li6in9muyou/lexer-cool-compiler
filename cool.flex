/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* This is a hack to
 * a) satisfy the cool compiler which expects yylex to be named cool_yylex (see below)
 * b) satisfy libfl > 2.5.39 which expects a yylex symbol
 * c) fix mangling errors of yylex when compiled with a c++ compiler
 * d) be as non-invasive as possible to the existing assignment code
 */
extern int cool_yylex();
extern "C" {
  int (&yylex) (void) = cool_yylex;
}

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
    if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
        YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

%}

%x STRING_LITERAL BLOCK_COMMENT LINE_COMMENT

%%

"=>"       { return (DARROW); }
"<-"       { return (ASSIGN); }
"<="       { return (LE); }

"class"|"Class" 		{ return (CLASS); }
"else" 					{ return (ELSE); }
"fi" 					{ return (FI); }
"if" 					{ return (IF); }
"in" 					{ return (IN); }
"inherits"				{ return (INHERITS); }
"let"					{ return (LET); }
"loop" 					{ return (LOOP); }
"pool" 					{ return (POOL); }
"then" 					{ return (THEN); }
"while" 				{ return (WHILE); }
"case" 					{ return (CASE); }
"esac"					{ return (ESAC); }
"of" 					{ return (OF); }
"new" 					{ return (NEW); }
"isvoid"				{ return (ISVOID); }
"not" 					{ return (NOT); }

"{" |
"}" |
"(" |
")" |
"." |
"," |
";" |
"~" |
"-" |
"=" |
"+" |
"<" |
"/" |
"*" |
"@" |
":"             { return (int) yytext[0]; }

"\n"            { curr_lineno += 1; }

\" { string_buf_ptr = string_buf; BEGIN STRING_LITERAL; }
<STRING_LITERAL>{
	[^\"\\] {
		*string_buf_ptr = *yytext;
		string_buf_ptr++;
	}

	\\. {
		switch(yytext[1]) {
		case 'n': *string_buf_ptr++ = '\n'; break;
		case 'r': *string_buf_ptr++ = '\r'; break;
		case 't': *string_buf_ptr++ = '\t'; break;
		case 'b': *string_buf_ptr++ = '\b'; break;
		case 'f': *string_buf_ptr++ = '\f'; break;
		case '\\':
		case '\'':
		case '\"':
			*string_buf_ptr++ = yytext[1]; break;
		}
	}

	\" {
		*string_buf_ptr = '\0';
		cool_yylval.symbol = stringtable.add_string(string_buf);
		BEGIN 0;
		return (STR_CONST);
	}
}

"(*" { BEGIN BLOCK_COMMENT; }
<BLOCK_COMMENT>{
	[^*\n]* {}

	"*"+[^*)\n]* {}

	\n { curr_lineno += 1; }

	"*)" { BEGIN 0; }
}

"--" { BEGIN LINE_COMMENT; }
<LINE_COMMENT>{
	.* {}

	\n { curr_lineno += 1; BEGIN 0; }
}

[0-9]+ {
	/* integers */
	cool_yylval.symbol = inttable.add_string(yytext);
	return (INT_CONST);
}

[A-Z][a-zA-Z_0-9]* {
	/* type id must start with uppercase letter */
	cool_yylval.symbol = idtable.add_string(yytext);
	return (TYPEID);
}

t[rR][uU][eE] {
	/* boolean literal for true and false */
	cool_yylval.boolean = 1;
	return (BOOL_CONST);
}

f[aA][lL][sS][eE] {
	cool_yylval.boolean = 0;
	return (BOOL_CONST);
}

[a-z][a-zA-Z_0-9]* {
	/* object id must start with lowercase letter */
	cool_yylval.symbol = idtable.add_string(yytext);
	return (OBJECTID);
}

[ \t]* {
	/* object id must starts with lowercase letter */
}

%%
