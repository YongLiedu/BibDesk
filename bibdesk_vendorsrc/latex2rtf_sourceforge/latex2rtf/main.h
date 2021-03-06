/* $Id: main.h,v 1.69 2005/01/18 06:19:46 prahl Exp $ */

#if defined(UNIX)
#define ENVSEP ':'
#define PATHSEP '/'
#endif

#if defined(MSDOS) || defined(OS2)
#define ENVSEP ';'
#define PATHSEP '\\'
#endif 

#if defined(VMS)
#define ENVSEP ','
#define PATHSEP ''
#endif

#if defined(MAC_CLASSIC)
#define ENVSEP '^'
#define PATHSEP ':'
#include "MainMain.h"
#endif

#ifdef HAS_STRDUP
#else
#define strdup my_strdup
#endif

#ifndef SEEK_SET
#define SEEK_SET 0
#define SEEK_CUR 1
#endif

#define ERROR 0
#define WARNING 1

#define MAXCOMMANDLEN 100

/* available values for alignment */
#define LEFT	  'l'
#define RIGHT	  'r'
#define CENTERED  'c'
#define JUSTIFIED 'j'

#define PATHMAX 255

/*** error constants ***/
#include <assert.h>
#include <stdio.h>

/*** interpret comment lines that follow the '%' with this string ***/
extern const char  * InterpretCommentString;

typedef int		bool;

void			diagnostics(int level, char *format,...);

extern			char *g_aux_name;
extern			char *g_toc_name;
extern			char *g_lof_name;
extern			char *g_lot_name;
extern			char *g_bbl_name;
extern			char *g_home_dir;
extern			char *progname;			/* name of the executable file */

extern bool		GermanMode;
extern bool		FrenchMode;
extern bool		RussianMode;
extern bool		CzechMode;
extern bool		pagenumbering;
extern int		headings;

extern int		g_verbosity_level;
extern int		RecursionLevel;

/* table  & tabbing variables */
extern long		pos_begin_kill;
extern int		tabcounter;
extern int		g_equation_column;
extern int		tabcounter;

extern bool		twocolumn;
extern bool		titlepage;

extern bool		g_processing_equation;
extern bool		g_processing_preamble;
extern bool		g_processing_figure;
extern bool		g_processing_table;
extern bool		g_processing_tabbing;
extern bool		g_processing_tabular;
extern bool		g_processing_eqnarray;
extern int		g_processing_arrays;
extern int		g_processing_fields;
extern int		g_dots_per_inch;

extern int		g_document_type;
extern int		g_document_bibstyle;

extern bool		g_fields_use_EQ;
extern bool		g_fields_use_REF;

extern int		g_equation_number;
extern bool		g_escape_parens;
extern bool		g_show_equation_number;
extern int		g_enumerate_depth;
extern bool		g_suppress_equation_number;
extern bool		g_aux_file_missing;
extern bool		g_bbl_file_missing;
extern char		g_charset_encoding_name[20];
extern int		g_fcharset_number;
extern int      g_graphics_package;
extern int      g_amsmath_package;

extern char		*g_figure_label;
extern char		*g_table_label;
extern char		*g_equation_label;
extern char		*g_section_label;
extern char		*g_config_path;
extern char		*g_script_dir;
extern char		g_field_separator;
extern char		*g_preamble;

extern double	g_png_equation_scale; 
extern double	g_png_figure_scale;
extern bool		g_latex_figures;
extern bool		g_endfloat_figures;
extern bool		g_endfloat_tables;
extern bool		g_endfloat_markers;

extern bool		g_equation_inline_rtf;
extern bool		g_equation_display_rtf;
extern bool		g_equation_inline_bitmap;
extern bool		g_equation_display_bitmap;
extern bool		g_equation_comment;
extern bool     g_equation_raw_latex;

extern bool 	g_tabular_display_rtf;
extern bool 	g_tabular_display_bitmap;

extern bool		g_little_endian;
extern bool		g_tableofcontents;

void fprintRTF(char *format, ...);
void putRtfCharEscaped(char cThis);
void putRtfStrEscaped(const char * string);
char *getTmpPath(void);
char *my_strdup(const char *str);
FILE *my_fopen(char *path, char *mode);

void debug_malloc(void);
