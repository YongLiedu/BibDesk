FasdUAS 1.101.10   ��   ��    k             l   0 ��  O    0  	  k   / 
 
     l   �� ��    ; 5 Get first, i.e. frontmost,  document and talk to it.         r    
    4   �� 
�� 
docu  m    ����   o      ���� 0 d        l   ������  ��        l      O       k          l   �� ��    - ' we can use whose right out of the box!          r      ! " ! n     # $ # 4    �� %
�� 
cobj % m    ����  $ l    &�� & 6    ' ( ' 2   ��
�� 
bibi ( E     ) * ) 1    ��
�� 
ckey * m     + +  DG   ��   " o      ���� 0 p      , - , l  ! !������  ��   -  . / . l  ! !�� 0��   0 * $ THINGS WE CAN DO WITH A PUBLICATION    /  1 2 1 l  ! Q 3 4 3 O   ! Q 5 6 5 k   % P 7 7  8 9 8 l  % %�� :��   : 1 + all properties give quite a lengthy output    9  ; < ; l  % %�� =��   =   get properties    <  > ? > l  % %������  ��   ?  @ A @ l  % %�� B��   B � � we can access all fields, but this has to be done in a two-step process for some AppleScript reason (see http://earthlingsoft.net/ssp/blog/2004/07/cocoa_and_applescript#810). The keys have to be surrounded by pipes.    A  C D C r   % * E F E 1   % (��
�� 
flds F o      ���� 0 f   D  G H G e   + / I I n   + / J K J o   , .���� 0 Journal   K o   + ,���� 0 f   H  L M L l  0 0������  ��   M  N O N l  0 0�� P��   P I C plurals as well as accessing a whole array of things  work as well    O  Q R Q n   0 6 S T S 1   3 5��
�� 
aunm T 2  0 3��
�� 
auth R  U V U l  7 7������  ��   V  W X W l  7 7�� Y��   Y - ' as does access to the local file's URL    X  Z [ Z l  7 7�� \��   \ � � This is nice but the whole differences between Unix and traditional AppleScript style paths seem to make it worthless => text item delimiters galore. See the arXiv download script for an example or, better even, suggest a nice solution.    [  ] ^ ] r   7 < _ ` _ 1   7 :��
�� 
lURL ` o      ���� 0 lf   ^  a b a l  = =������  ��   b  c d c l  = =�� e��   e #  we can easily set properties    d  f g f r   = F h i h m   = @ j j  http://localhost/lala/    i 1   @ E��
�� 
rURL g  k l k l  G G������  ��   l  m n m l  G G�� o��   o + % and get the underlying BibTeX record    n  p�� p r   G P q r q 1   G L��
�� 
BTeX r o      ���� 0 bibtexrecord BibTeXRecord��   6 o   ! "���� 0 p   4   p    2  s t s l  R R������  ��   t  u v u l  R R�� w��   w + % GENERATING AND DELETING PUBLICATIONS    v  x y x l  R R�� z��   z   let's make a new record    y  { | { r   R h } ~ } I  R d���� 
�� .corecrel****      � null��    �� � �
�� 
kocl � m   V W��
�� 
bibi � �� ���
�� 
insh � l  Z ^ ��� � n   Z ^ � � �  ;   ] ^ � 2  Z ]��
�� 
bibi��  ��   ~ o      ���� 0 n   |  � � � l  i i�� ���   � ? 9 this is initially empty, so fill it with a BibTeX string    �  � � � r   i t � � � o   i l���� 0 bibtexrecord BibTeXRecord � n       � � � 1   o s��
�� 
BTeX � o   l o���� 0 n   �  � � � l  u u�� ���   �    get rid of the new record    �  � � � I  u |�� ���
�� .coredelonull��� ��� obj  � o   u x���� 0 n  ��   �  � � � l  } }������  ��   �  � � � l  } }�� ���   � !  MANIPULATING THE SELECTION    �  � � � l  } }�� ���   � L F Play with the selection and put styled bibliography on the clipboard.    �  � � � r   } � � � � 6  } � � � � 2  } ���
�� 
bibi � E   � � � � � 1   � ���
�� 
ckey � m   � � � �  DG    � o      ���� 0 ar   �  � � � r   � � � � � o   � ����� 0 ar   � 1   � ���
�� 
sele �  � � � I  � �������
�� .BDSKsbtcnull��� ��� obj ��  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   �   AUTHORS    �  � � � l  � ��� ���   � D > we can also query all authors present in the current document    �  � � � e   � � � � 4  � ��� �
�� 
auth � m   � �����  �  � � � r   � � � � � 4   � ��� �
�� 
auth � m   � � � �  M. K. Murray    � o      ���� 0 a   �  � � � e   � � � � n   � � � � � 2  � ���
�� 
bibi � o   � ����� 0 a   �  � � � l  � �������  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   �   FILTERING AND SEARCHING    �  � � � l  � ��� ���   � y s We can get and set the filter field of each document and get the list of publications that is currently displayed.    �  � � � l  � ��� ���   ���In addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.    �  � � � Z   � � � ��� � � =  � � � � � 1   � ���
�� 
filt � m   � � � �       � r   � � � � � m   � � � �  gerbe    � 1   � ���
�� 
filt��   � r   � � � � � m   � � � �       � 1   � ���
�� 
filt �  � � � e   � � � � 1   � ���
�� 
disp �  � � � e   � � � � I  � ����� �
�� .BDSKsrchlist    ��� obj ��   � �� ���
�� 
for  � m   � � � �  gerbe   ��   �  � � � l  � ��� ���   � r l When writing an AppleScript for completion support in other applications use the 'for completion' parameter    �  � � � e   �  � � I  � ���� �
�� .BDSKsrchlist    ��� obj ��   � �� � �
�� 
for  � m   � � � �  gerbe    � �� ���
�� 
cmpl � m   � ���
�� savoyes ��   �  ��� � l ������  ��  ��    o    ���� 0 d      d      � � � l ������  ��   �  � � � l �� ���   � � � The search command works also at application level. It will either search every document in that case, or the one it is addressed to.    �  � � � I ���� �
�� .BDSKsrchlist    ��� obj ��   � �� ���
�� 
for  � m   � �  gerbe   ��   �  � � � I �� � 
�� .BDSKsrchlist    ��� obj  � 4 ��
�� 
docu m  ��   �~�}
�~ 
for  m    gerbe   �}   �  l �|�|    y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.     l �{�z�{  �z   	�y	 O /

 r  %. m  %( 
 chen    1  (-�x
�x 
filt 2  "�w
�w 
docu�y   	 m     �null     ߀�� KvBibdesk.app P� �0    ���p��� �0                 [W�(.��ఐ)BDSK   alis    b  Kalle                      |%�JH+   KvBibdesk.app                                                     ~��-�<        ����  	                builds    |%�:      �-�     Kv d� %�  "E  ,Kalle:Users:ssp:Developer:builds:Bibdesk.app    B i b d e s k . a p p    K a l l e  &Users/ssp/Developer/builds/Bibdesk.app  /    
��  ��     l     �v�u�v  �u   �t l     �s�r�s  �r  �t       �q�p�o�n�m�l�k�j�q   �i�h�g�f�e�d�c�b�a�`�_�^�]�\�[�Z
�i .aevtoappnull  �   � ****�h 0 d  �g 0 p  �f 0 f  �e 0 lf  �d 0 bibtexrecord BibTeXRecord�c 0 n  �b 0 ar  �a 0 a  �`  �_  �^  �]  �\  �[  �Z   �Y�X�W�V
�Y .aevtoappnull  �   � **** k    0    �U�U  �X  �W     .�T�S�R!�Q +�P�O�N�M�L�K�J�I�H j�G�F�E�D�C�B�A�@�? ��>�=�< ��;�: � � ��9�8 ��7 ��6�5 �
�T 
docu�S 0 d  
�R 
bibi!  
�Q 
ckey
�P 
cobj�O 0 p  
�N 
flds�M 0 f  �L 0 Journal  
�K 
auth
�J 
aunm
�I 
lURL�H 0 lf  
�G 
rURL
�F 
BTeX�E 0 bibtexrecord BibTeXRecord
�D 
kocl
�C 
insh�B 
�A .corecrel****      � null�@ 0 n  
�? .coredelonull��� ��� obj �> 0 ar  
�= 
sele
�< .BDSKsbtcnull��� ��� obj �; 0 a  
�: 
filt
�9 
disp
�8 
for 
�7 .BDSKsrchlist    ��� obj 
�6 
cmpl
�5 savoyes �V1�-*�k/E�O� �*�-�[�,\Z�@1�k/E�O� -*�,E�O��,EO*�-�,EO*�,E�Oa *a ,FO*a ,E` UO*a �a *�-6a  E` O_ _ a ,FO_ j O*�-�[�,\Za @1E` O_ *a ,FO*j O*�k/EO*�a /E` O_ �-EO*a  ,a !  a "*a  ,FY a #*a  ,FO*a $,EO*a %a &l 'O*a %a (a )a *a  'OPUO*a %a +l 'O*�k/a %a ,l 'O*�- a -*a  ,FUU "" �4#
�4 
docu# �$$  B D   t e s t . b i b %% &�3�2& �1'
�1 
docu' �((  B D   t e s t . b i b
�3 
bibi�2  �0)*�0 0 Url  ) �++ V h t t p : / / d e . a r x i v . o r g / p d f / m a t h . D G / 0 1 0 6 1 7 9 . p d f* �/,-�/ 0 Journal  , �.. & C o m m u n .   M a t h .   P h y s .- �./0�. 	0 Title  / �11 f { H i g g s   f i e l d s ,   b u n d l e   g e r b e s   a n d   s t r i n g   s t r u c t u r e s }0 �-23�- 0 Year  2 �44  2 0 0 33 �,56�, 	0 Pages  5 �77  5 4 1 - - 5 5 56 �+89�+ 0 Rss-Description  8 �::  9 �*;<�* 0 Abstract  ; �==  < �)>?�) 0 Keywords  > �@@  ? �(AB�( 	0 Month  A �CC  B �'DE�' 
0 Number  D �FF  E �&GH�& 0 	Local-Url  G �II X / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d fH �%JK�% 
0 Eprint  J �LL * a r X i v : m a t h . D G / 0 1 0 6 1 7 9K �$MN�$ 
0 Volume  M �OO  2 4 3N �#PQ�# 
0 Annote  P �RR  Q �"S�!�" 
0 Author  S �TT : M .   K .   M u r r a y   a n d   D .   S t e v e n s o n�!   �UU X / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d f �VV� @ a r t i c l e { m a t h . D G / 0 1 0 6 1 7 9 , 
 	 A u t h o r   =   { M .   K .   M u r r a y   a n d   D .   S t e v e n s o n } , 
 	 E p r i n t   =   { a r X i v : m a t h . D G / 0 1 0 6 1 7 9 } , 
 	 J o u r n a l   =   { C o m m u n .   M a t h .   P h y s . } , 
 	 L o c a l - U r l   =   { / U s e r s / s s p / Q u e l l e n / M a t h e / m a t h . D G - 0 1 0 6 1 7 9 . p d f } , 
 	 P a g e s   =   { 5 4 1 - - 5 5 5 } , 
 	 T i t l e   =   { { H i g g s   f i e l d s ,   b u n d l e   g e r b e s   a n d   s t r i n g   s t r u c t u r e s } } , 
 	 U r l   =   { h t t p : / / l o c a l h o s t / l a l a / } , 
 	 V o l u m e   =   { 2 4 3 } , 
 	 Y e a r   =   { 2 0 0 3 } } WW X� �X �Y
� 
docuY �ZZ  B D   t e s t . b i b
�  
bibi�  �[� [  \]\ ^^ _��_ �`
� 
docu` �aa  B D   t e s t . b i b
� 
bibi� ] bb c��c �d
� 
docud �ee  B D   t e s t . b i b
� 
bibi�  ff g�hg �i
� 
docui �jj  B D   t e s t . b i b
� 
authh �kk  M .   K .   M u r r a y�p  �o  �n  �m  �l  �k  �j   ascr  ��ޭ