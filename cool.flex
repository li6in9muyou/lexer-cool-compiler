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
unsigned int block_comment_nested_level = 0;
%}

%x STRING_LITERAL BLOCK_COMMENT LINE_COMMENT DISCARD_UNTIL_NEWLINE_OR_QUOTE UNTIL_NEWLINE

%%

"=>"       { return (DARROW); }
"<-"       { return (ASSIGN); }
"<="       { return (LE); }

(?i:class) 		        { return (CLASS); }
(?i:else) 				{ return (ELSE); }
(?i:fi) 				{ return (FI); }
(?i:if) 				{ return (IF); }
(?i:in) 				{ return (IN); }
(?i:inherits)			{ return (INHERITS); }
(?i:let)				{ return (LET); }
(?i:loop) 				{ return (LOOP); }
(?i:pool) 				{ return (POOL); }
(?i:then) 				{ return (THEN); }
(?i:while) 				{ return (WHILE); }
(?i:case) 				{ return (CASE); }
(?i:esac)				{ return (ESAC); }
(?i:of) 				{ return (OF); }
(?i:new) 				{ return (NEW); }
(?i:isvoid)				{ return (ISVOID); }
(?i:not) 				{ return (NOT); }

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

<DISCARD_UNTIL_NEWLINE_OR_QUOTE>{
	[^\"\n]* {}

	\n { curr_lineno += 1; BEGIN 0; }
	\" { BEGIN 0; }
}

\" { string_buf_ptr = string_buf; BEGIN STRING_LITERAL; }
<STRING_LITERAL>{
	/* special characters */

	/* closing quote */
	\" {
		*string_buf_ptr = '\0';
		cool_yylval.symbol = stringtable.add_string(string_buf);
		BEGIN 0;
		return (STR_CONST);
	}

	/* null and escaped null */
	"\0" {
		BEGIN DISCARD_UNTIL_NEWLINE_OR_QUOTE;
		cool_yylval.error_msg = "String contains null character.";
		return (ERROR);
	}
	
	\\\0 {
		BEGIN DISCARD_UNTIL_NEWLINE_OR_QUOTE;
		cool_yylval.error_msg = "String contains escaped null character.";
		return (ERROR);
	}

	/* rejects naked newline, accepts escaped newline */
	\n {
		BEGIN 0;
		curr_lineno += 1;
		cool_yylval.error_msg = "Unterminated string constant";
		return (ERROR);
	}
	
	\\\n {
		*string_buf_ptr++ = '\n';
		curr_lineno += 1;

        if (string_buf_ptr - string_buf > 1024) {
            BEGIN DISCARD_UNTIL_NEWLINE_OR_QUOTE;
            cool_yylval.error_msg = "String constant too long";
            return (ERROR);
        }
	}

	\\. {
		switch(yytext[1]) {
		case 'n': *string_buf_ptr++ = '\n'; break;
		case 't': *string_buf_ptr++ = '\t'; break;
		case 'b': *string_buf_ptr++ = '\b'; break;
		case 'f': *string_buf_ptr++ = '\f'; break;
		default:
			*string_buf_ptr++ = yytext[1]; break;
		}

        if (string_buf_ptr - string_buf > 1024) {
            BEGIN DISCARD_UNTIL_NEWLINE_OR_QUOTE;
            cool_yylval.error_msg = "String constant too long";
            return (ERROR);
        }
	}

	<<EOF>> {
		cool_yylval.error_msg = "EOF in string constant";
		BEGIN 0;
		return (ERROR);
	}

	/* end of special character */

	. {
		*string_buf_ptr = *yytext;
		string_buf_ptr++;

		if (string_buf_ptr - string_buf > 1024) {
			BEGIN DISCARD_UNTIL_NEWLINE_OR_QUOTE;
			cool_yylval.error_msg = "String constant too long";
			return (ERROR);
		}
	}
}

"(*" { 
	block_comment_nested_level = 1;
	BEGIN BLOCK_COMMENT;
}
<BLOCK_COMMENT>{
	/* special characters */
	"(*" {
		block_comment_nested_level += 1;
	}

	"*)" {
		block_comment_nested_level -= 1;
		if(block_comment_nested_level == 0) {
			BEGIN 0;
		}
	}

	\n { curr_lineno += 1; }
	/* end of special characters */

	. {}

	<<EOF>> {
		cool_yylval.error_msg = "EOF in comment";
		BEGIN 0;
		return (ERROR);
	}
}


"*)" {
	cool_yylval.error_msg = "Unmatched *)";
	return (ERROR);
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

[ \t\f\013\015]* {}

. {
	cool_yylval.error_msg = yytext;
	return (ERROR);
}

%%
