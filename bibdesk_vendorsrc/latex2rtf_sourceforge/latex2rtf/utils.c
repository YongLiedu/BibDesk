
/*
 * utils.c - handy routines
 * 
 * Copyright (C) 1995-2002 The Free Software Foundation
 * 
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 * 
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59
 * Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 * 
 * This file is available from http://sourceforge.net/projects/latex2rtf/
 * 
 * Authors: 1995-1997 Ralf Schlatterbeck 1998-2000 Georg Lehner 2001-2002 Scott
 * Prahl
 */

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include "main.h"
#include "utils.h"
#include "parser.h"

/******************************************************************************
 purpose:  returns true if n is odd
******************************************************************************/
int odd(int n)
{
    return (n & 1);
}

/******************************************************************************
 purpose:  returns true if n is even
******************************************************************************/
int even(int n)
{
    return (!(n & 1));
}

/******************************************************************************
 purpose:  rounds to nearest integer. round() in math.h is not always present
 *****************************************************************************/
double my_rint(double nr)
{
  double f = floor(nr);
  double c = ceil(nr);
  return (((c-nr) >= (nr-f)) ? f :c);
}

/******************************************************************************
 purpose:  count the number of occurences of the string t in the string s
******************************************************************************/
int strstr_count(const char *s, char *t)
{
    int n = 0;
    size_t len;
    char *p;

    if (t == NULL || s == NULL)
        return n;

    len = strlen(t);
    p = strstr(s, t);

    while (p) {
        n++;
        p = strstr(p + len - 1, t);
    }

    return n;
}

/******************************************************************************
 purpose:  returns a new string with n characters from s (with '\0' at the end)
******************************************************************************/
char *my_strndup(const char *src, size_t n)
{
    char *dst;

    dst = (char *) calloc(n + 1, sizeof(char));
    if (dst == NULL)
        return NULL;

    strncpy(dst, src, n);

    return dst;
}

/******************************************************************************
 purpose:  returns a new string consisting of s+t
******************************************************************************/
char *strdup_together(const char *s, const char *t)
{
    char *both;
	size_t siz;
	
    if (s == NULL) {
        if (t == NULL)
            return NULL;
        return strdup(t);
    }
    if (t == NULL)
        return strdup(s);

    siz = strlen(s) + strlen(t) + 1;
    both = malloc(siz);
    if (both == NULL)
        diagnostics(ERROR, "Could not allocate memory for both strings.");

    my_strlcpy(both, s, siz);
    my_strlcat(both, t, siz);
    return both;
}

/******************************************************************************
 purpose:  returns a new string consisting of s+t+u
******************************************************************************/
char *strdup_together3(const char *s, const char *t, const char *u)
{
    char *two, *three;
	two = strdup_together(s,t);
	three = strdup_together(two,u);
	free(two);
	return three;
}

/******************************************************************************
 purpose:  returns a new string consisting of s+t+u+v
******************************************************************************/
char *strdup_together4(const char *s, const char *t, const char *u, const char *v)
{
    char *four, *three;
	three = strdup_together3(s,t,u);
	four = strdup_together(three,v);
	free(three);
	return four;
}

/******************************************************************************
 purpose:  duplicates a string but removes TeX  %comment\n
******************************************************************************/
char *strdup_nocomments(const char *s)
{
    char *p, *dup;

    if (s == NULL)
        return NULL;

    dup = malloc(strlen(s) + 1);
    p = dup;

    while (*s) {
        while (*s == '%') {     /* remove comment */
            s++;                /* one char past % */
            while (*s && *s != '\n')
                s++;            /* find end of line */
            if (*s == '\0')
                goto done;
            s++;                /* first char after comment */
        }
        *p = *s;
        p++;
        s++;
    }
  done:
    *p = '\0';
    return dup;
}

/******************************************************************************
 purpose:  duplicates a string without including spaces or newlines
******************************************************************************/
char *strdup_noblanks(const char *s)
{
    char *p, *dup;

    if (s == NULL)
        return NULL;
    while (*s == ' ' || *s == '\n')
        s++;                    /* skip to non blank */
    dup = malloc(strlen(s) + 1);
    p = dup;
    while (*s) {
        *p = *s;
        if (*p != ' ' && *p != '\n')
            p++;                /* increment if non-blank */
        s++;
    }
    *p = '\0';
    return dup;
}

/*************************************************************************
purpose: duplicate text with only a..z A..Z 0..9 and _
**************************************************************************/
char *strdup_nobadchars(const char *text)
{
    char *dup, *s;

    dup = strdup_noblanks(text);
    s = dup;

    while (*s) {
        if (!('a' <= *s && *s <= 'z') && !('A' <= *s && *s <= 'Z') && !('0' <= *s && *s <= '9'))
            *s = '_';
        s++;
    }

    return dup;
}

/******************************************************************************
 purpose:  duplicates a string without newlines and CR replaced by '\n' or '\r'
******************************************************************************/
char *strdup_printable(const char *s)
{
    char *dup;
    int i;
    
    if (s == NULL) return NULL;

    dup = malloc(2*strlen(s));

    i=0;
    while (*s) {
        if (*s=='\r') {
            dup[i++]='\\';
            dup[i++]='r';
         } else if (*s=='\n') {
            dup[i++]='\\';
            dup[i++]='n';
         } else if (*s=='\t') {
            dup[i++]='\\';
            dup[i++]='t';
         } else 
            dup[i++]=*s;
         s++;
    }
    dup[i]='\0';
        
    return dup;
}

/******************************************************************************
 purpose:  duplicates a string without newlines and CR replaced by '\n' or '\r'
******************************************************************************/
void strncpy_printable(char* dst, char *src, int n)
{
    int i=0;
    
    if (dst == NULL)
        return;

    while (i<n-1 && *src) {

        if (*src=='\r') {
            dst[i++]='\\';
            dst[i++]='r';
         } else if (*src=='\n') {
            dst[i++]='\\';
            dst[i++]='n';
         } else if (*src=='\t') {
            dst[i++]='\\';
            dst[i++]='t';
         } else 
            dst[i++]=*src;
         src++;
    }
    
    dst[i]='\0';
}

/******************************************************************************
 purpose:  duplicates a string without spaces or newlines at front or end
******************************************************************************/
char *strdup_noendblanks(const char *s)
{
    char *p, *t;

    if (s == NULL)
        return NULL;
    if (*s == '\0')
        return strdup("");

	/* find pointer to first non-space character in string */
    t = (char *) s;
    while (*t == ' ' || *t == '\n')
        t++;                    /* first non blank char */

	/* find pointer to last non-space character in string */
    p = (char *) s + strlen(s) - 1;
    while (p >= t && (*p == ' ' || *p == '\n'))
        p--;                    /* last non blank char */

    if (t > p)
        return strdup("");
    return my_strndup(t, (size_t) (p - t + 1));
}
/******************************************************************************
  purpose: return a copy of tag from \label{tag} in the string text
 ******************************************************************************/
char *ExtractLabelTag(const char *text)
{
    char *s, *label_with_spaces, *label;

    s = strstr(text, "\\label{");
    if (!s)
        s = strstr(text, "\\label ");
    if (!s)
        return NULL;

    s += strlen("\\label");
    PushSource(NULL, s);
    label_with_spaces = getBraceParam();
    PopSource();
    label = strdup_nobadchars(label_with_spaces);
    free(label_with_spaces);

    diagnostics(4, "LabelTag = <%s>", (label) ? label : "missing");
    return label;
}

/******************************************************************************
 purpose: provide functionality of getBraceParam() for strings
 
 		if s contains "aaa {stuff}cdef", then  
 			parameter = getStringBraceParam(&s)
 			
 		  gives
 			parameter = "stuff"
 			s="cdef"
 ******************************************************************************/
char *getStringBraceParam(char **s)

{
	char *p_start, *p, *parameter, last;
	int braces = 1;
		
	/* find start of parameter */
	if (*s == NULL) return NULL;
	p_start = strchr(*s,'{');
	if (p_start==NULL) return NULL;

	/* scan to enclosing brace */
	p_start++;
	p=p_start;	
	last = '\0';
	while (*p != '\0' && braces > 0) {
		if (*p == '{' && last != '\\')
			braces++;
		if (*p == '}' && last != '\\')
			braces--;
		last = *p;
		p++;
	}
	
	parameter = my_strndup(p_start, p-p_start-1);
	*s = p;

	diagnostics(6,"Extract parameter=<%s> after=<%s>", parameter, *s); 
	
	return parameter;
	
}


/******************************************************************************
  purpose: remove 'tag{contents}' from text and return contents
           note that tag should typically be "\\caption"
 ******************************************************************************/
char *ExtractAndRemoveTag(char *tag, char *text)
{
    char *s, *contents, *start=NULL;

    if (text==NULL || *text=='\0') return NULL;
    
    s = text;
    diagnostics(5, "target tag = <%s>", tag);
    diagnostics(5, "original text = <%s>", text);

    while (s) {                 /* find start of caption */
        start = strstr(s, tag);
        if (!start)
            return NULL;
        s = start + strlen(tag);
        if (*s == ' ' || *s == '{')
            break;
    }

	contents = getStringBraceParam(&s);
	if (contents == NULL) return NULL;
	
	/* erase "tag{contents}" */
    do
        *start++ = *s++;
    while (*s);               
    *start = '\0';

    diagnostics(5, "final contents = <%s>", contents);
    diagnostics(5, "final text = <%s>", text);

    return contents;
}

/* this extracts a comma-delimited, key-value pair from the string s
   the string is untouched, and the return value from the function is
   a pointer to the next character in the string to be parsed to get
   the next pair.
   
   EXAMPLE: s= "  option=param,singleoptionname,opt2=crazy"
   first  iteration return="singleoptionname,opt2=crazy", key="option", value="param"
   second iteration return="opt2=crazy", key="singleoptionname", value=NULL
   third  iteration return=NULL, key="opt2", value="crazy"
*/  
   
char * keyvalue_pair(char *s, char **key, char **value)
{
	char *k, *v;	
	*key = NULL;
	*value = NULL;
	if (s==NULL) return NULL;
		
	/* skip any blanks at start */
	while (*s == ' ') s++;

	if (*s=='\0') return NULL;  /*possibly all blanks*/
	
	/* find the end of the key */
	k = s;
	while (*k != '=' && *k != ',' && *k != '\0') 
		k++;
		
	/* allocate and copy string into the key */
	*key = my_strndup(s, k-s);
	
	if (*k == '\0') return NULL;
	
	if (*k == ',') return k+1;
	
	/* '=' found, now parse value */
	s = k+1;
	
	/* skip any blanks at start */
	while (*s == ' ') s++;
	
	/* find the end of the value */
	v = s;
	while (*v != ',' && *v != '\0') {
	    if (*v == '{')
		while (*(++v) != '}')
		    ;
	    else
		v++;
	}
	/* allocate and copy this into the value */
	*value = my_strndup(s, v-s);
	
	if (*v == '\0') return NULL;
	return v+1;
}

int getStringDimension(char *s)
{
	int size = 0;
	
	if (s != NULL) {
		PushSource(NULL, s);
		size = getDimension();
		PopSource();
	}
	
	return size;
}

void show_string(int level, const char *s, const char *label)
{
	int width=100;
	long i;
	char c;
	long len;
	
	if (g_verbosity_level<level) return;
		
	if (s == NULL) {
		diagnostics(WARNING, "\n%s: NULL",label);
		return;
	}
		
	len = strlen(s);
	fprintf(stderr, "\n%s: ", label);

	for (i=0; i<len; i++) {
	
		if (i==width)
			fprintf(stderr, "\n%-*d: ", (int) strlen(label), (int) strlen(s));
		else if (i>1 && i % width == 0) 
			fprintf(stderr, "\n%s: ",label);
		c = s[i];
		if (c == '\n') c = '=';
		if (c == '\0') c = '*';
		fprintf(stderr,"%c",c);
	}
}

/* these next two routines fall under the copyright banner below.  The
names of the routines have had 'my_' prepended to avoid conflicting
with existing versions in string.h  */

/*
 * Copyright (c) 1998 Todd C. Miller <Todd.Miller@courtesan.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * Copy src to string dst of size siz.  At most siz-1 characters
 * will be copied.  Always NUL terminates (unless siz == 0).
 * Returns strlen(src); if retval >= siz, truncation occurred.
 */
size_t
my_strlcpy(char *dst, const char *src, size_t siz)
{
        char *d = dst;
        const char *s = src;
        size_t n = siz;

        /* Copy as many bytes as will fit */
        if (n != 0) {
                while (--n != 0) {
                        if ((*d++ = *s++) == '\0')
                                break;
                }
        }

        /* Not enough room in dst, add NUL and traverse rest of src */
        if (n == 0) {
                if (siz != 0)
                        *d = '\0';                /* NUL-terminate dst */
                while (*s++)
                        ;
        }

        return(s - src - 1);        /* count does not include NUL */
}

/*
 * Appends src to string dst of size siz (unlike strncat, siz is the
 * full size of dst, not space left).  At most siz-1 characters
 * will be copied.  Always NUL terminates (unless siz <= strlen(dst)).
 * Returns strlen(src) + MIN(siz, strlen(initial dst)).
 * If retval >= siz, truncation occurred.
 */
size_t
my_strlcat(char *dst, const char *src, size_t siz)
{
        char *d = dst;
        const char *s = src;
        size_t n = siz;
        size_t dlen;

        /* Find the end of dst and adjust bytes left but don't go past end */
        while (n-- != 0 && *d != '\0')
                d++;
        dlen = d - dst;
        n = siz - dlen;

        if (n == 0)
                return(dlen + strlen(s));
        while (*s != '\0') {
                if (n != 1) {
                        *d++ = *s;
                        n--;
                }
                s++;
        }
        *d = '\0';

        return(dlen + (s - src));        /* count does not include NUL */
}
