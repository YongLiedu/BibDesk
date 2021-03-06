/*
 * Copyright (c) 1995-2007, Index Data
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of Index Data nor the names of its contributors
 *       may be used to endorse or promote products derived from this
 *       software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
/* $Id: logrpn.h,v 1.13 2007/01/03 08:42:14 adam Exp $ */

/**
 * \file logrpn.h
 * \brief Header for Z39.50 Query Printing
 */

#ifndef YAZ_LOGRPN_H
#define YAZ_LOGRPN_H

#include <yaz/yconfig.h>
#include <yaz/proto.h>
#include <yaz/wrbuf.h>

YAZ_BEGIN_CDECL

YAZ_EXPORT void log_rpn_query(Z_RPNQuery *rpn);
YAZ_EXPORT void log_rpn_query_level(int loglevel, Z_RPNQuery *rpn);

YAZ_EXPORT void log_scan_term(Z_AttributesPlusTerm *zapt, oid_value ast);
YAZ_EXPORT void log_scan_term_level(int loglevel, 
                                    Z_AttributesPlusTerm *zapt, oid_value ast);

YAZ_EXPORT void yaz_log_zquery(Z_Query *q);
YAZ_EXPORT void yaz_log_zquery_level(int loglevel, Z_Query *q);

YAZ_EXPORT void wrbuf_diags(WRBUF b, int num_diagnostics,Z_DiagRec **diags);
YAZ_EXPORT void wrbuf_put_zquery(WRBUF b, const Z_Query *q);

YAZ_END_CDECL

#endif
/*
 * Local variables:
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 * vim: shiftwidth=4 tabstop=8 expandtab
 */

