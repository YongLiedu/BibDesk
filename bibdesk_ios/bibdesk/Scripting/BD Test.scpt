FasdUAS 1.101.10   ��   ��    k             l      �� ��   ��
This is a sample script to show AppleScript support for BibDesk. 
When you run this script, it creates a new document. So any 
currently opened document in Bibdesk should not be affected.

If you want to inspect the return value of a particular 
line in this script, insert 'return result' after that line 
and run the script. 

You can inspect the supported classes and commands 
in the AppleScript library. In the Script Editor, choose 
File > Open Dictionary�, or Shift-Command-O, and 
select Bibdesk. 

For more information about BibDesk, including a collection of
AppleScripts, see the Bibdesk home page at 
http://bibdesk.sourgeforge.net
       	  l     ������  ��   	  
  
 l   � ��  O    �    k   �       l   �� ��      start BibDesk         I   	������
�� .miscactvnull��� ��� null��  ��        l  
 
������  ��        l  
 
�� ��       and create a new document         I  
 ���� 
�� .corecrel****      � null��    �� ��
�� 
kocl  m    ��
�� 
docu��        l   ������  ��       !   l   �� "��   " ; 5 get first, i.e. frontmost,  document and talk to it.    !  # $ # r     % & % 4   �� '
�� 
docu ' m    ����  & o      ���� 0 thedoc theDoc $  ( ) ( l   ������  ��   )  * + * l  � , - , O   � . / . k   � 0 0  1 2 1 l   ������  ��   2  3 4 3 l   �� 5��   5 + % GENERATING AND DELETING PUBLICATIONS    4  6 7 6 l   �� 8��   8 %  make some BibTeX record to use    7  9 : 9 l   �� ;��   ; #  let's make a new publication    :  < = < r    + > ? > I   )���� @
�� .corecrel****      � null��   @ �� A B
�� 
kocl A m     ��
�� 
bibi B �� C��
�� 
insh C l  ! % D�� D n   ! % E F E  ;   $ % F 2  ! $��
�� 
bibi��  ��   ? o      ���� 0 newpub newPub =  G H G l  , ,�� I��   I ? 9 this is initially empty, so fill it with a BibTeX string    H  J K J l  , ,�� L��   L > 8 note: this can only be set before doing any other edit!    K  M N M r   , 1 O P O m   , - Q Q s m@article{McCracken:2005, Author = {M. McCracken and A. Maxwell}, Title = {Working with BibDesk.},Year={2005}}    P n       R S R 1   . 0��
�� 
BTeX S o   - .���� 0 newpub newPub N  T U T l  2 2�� V��   V + % we can get the BibTeX record as well    U  W X W r   2 7 Y Z Y l  2 5 [�� [ n   2 5 \ ] \ 1   3 5��
�� 
BTeX ] o   2 3���� 0 newpub newPub��   Z o      ���� "0 thebibtexrecord theBibTeXRecord X  ^ _ ^ l  8 8�� `��   ` %  get rid of the new publication    _  a b a I  8 =�� c��
�� .coredelonull���     obj  c o   8 9���� 0 newpub newPub��   b  d e d l  > >�� f��   f / ) a shortcut to creating a new publication    e  g h g r   > Q i j i I  > O���� k
�� .corecrel****      � null��   k �� l m
�� 
kocl l m   @ A��
�� 
bibi m �� n o
�� 
prdt n K   B F p p �� q��
�� 
BTeX q o   C D���� "0 thebibtexrecord theBibTeXRecord��   o �� r��
�� 
insh r l  G K s�� s n   G K t u t  ;   J K u 2  G J��
�� 
bibi��  ��   j o      ���� 0 newpub newPub h  v w v l  R R������  ��   w  x y x l  R R�� z��   z !  MANIPULATING THE SELECTION    y  { | { l  R R�� }��   } L F Play with the selection and put styled bibliography on the clipboard.    |  ~  ~ r   R h � � � l  R d ��� � 6  R d � � � 2  R U��
�� 
bibi � E   X c � � � 1   Y ]��
�� 
ckey � m   ^ b � �  	McCracken   ��   � o      ���� 0 somepubs somePubs   � � � r   i r � � � o   i l���� 0 somepubs somePubs � l      ��� � 1   l q��
�� 
sele��   �  � � � I  s x������
�� .BDSKsbtcnull��� ��� obj ��  ��   �  � � � l  y y�� ���   �   get the selection    �  � � � r   y � � � � l  y ~ ��� � 1   y ~��
�� 
sele��   � o      ���� 0 theselection theSelection �  � � � l  � ��� ���   �   and get its first item    �  � � � r   � � � � � n   � � � � � 4   � ��� �
�� 
cobj � m   � �����  � o   � ����� 0 theselection theSelection � o      ���� 0 thepub thePub �  � � � l  � �������  ��   �  � � � l  � ��� ���   � , & ACCESSING PROPERTIES OF A PUBLICATION    �  � � � l  � � � � O   � � � � k   � � �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 1 + all properties give quite a lengthy output    �  � � � l  � ��� ���   �   get properties    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � I C plurals as well as accessing a whole array of things  work as well    �  � � � n   � � � � � 1   � ���
�� 
aunm � 2  � ���
�� 
auth �  � � � l  � �������  ��   �  � � � l  � ��� ���   � . ( as does access to the local file's path    �  � � � r   � � � � � 1   � ���
�� 
lURL � o      ���� 0 thepath thePath �  � � � l  � ��� ���   � Note this is a POSIX style path, unlike the value of the field "Local-URL". To use it in AppleScript, e.g. to open the file with Finder, translate it into an AppleScript style path as in the next line. AppleScript's is added because 'POSIX file' is not a Bibdesk command.    �  � � � l  � ��� ���   � &  AppleScript's POSIX file thePath    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � #  we can easily set properties    �  � � � r   � � � � � m   � � � �  http://localhost/lala/    � o      ���� 0 theurl theURL �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 0 * we can access all fields and their values    �  � � � r   � � � � � 4   � ��� �
�� 
bfld � m   � � � �  Author    � o      ���� 0 thefield theField �  � � � e   � � � � n   � � � � � 1   � ���
�� 
fldv � 4   � ��� �
�� 
bfld � m   � � � �  Title    �  � � � r   � � � � � m   � � � �  SourceForge    � n       � � � 1   � ���
�� 
fldv � 4   � ��� �
�� 
bfld � m   � � � �  Journal    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � J D we can also get a list of all non-empty fields and their properties    �  � � � r   � � � � � n   � � � � � 1   � ���
�� 
pnam � 2  � ���
�� 
bfld � o      ����  0 nonemptyfields nonEmptyFields �  � � � l  � ������  �   �  �  � l  � ��~�~    
 CITE KEYS      l  � ��}�}   8 2you can access the cite key and generate a new one     e   � � 1   � ��|
�| 
ckey 	 r   � �

 1   � ��{
�{ 
gcky 1   � ��z
�z 
ckey	  l   �y�x�y  �x    l   �w�w     AUTHORS     l   �v�v   7 1 we can also query all authors in the publciation     r   
 4  �u
�u 
auth m  �t�t  o      �s�s 0 	theauthor 	theAuthor  l �r�r   E ? this is the normalized name of the form 'von Last, First, Jr.'     n   1  �q
�q 
pnam o  �p�p 0 	theauthor 	theAuthor  �o  l �n�m�n  �m  �o   � o   � ��l�l 0 thepub thePub �   thePub    � !"! l �k�j�k  �j  " #$# l �i%�i  % !  work again on the document   $ &'& l �h�g�h  �g  ' ()( l �f*�f  *   AUTHORS   ) +,+ l �e-�e  - � � we can also query all authors present in the current document. To find an author by name, it is preferrable to use the (normalized) name. You can also use the 'full name' property though.   , ./. r  $010 e   22 4   �d3
�d 
auth3 m  44  McCracken, M.   1 o      �c�c 0 	theauthor 	theAuthor/ 565 l %%�b7�b  7 $  and find all his publications   6 898 r  %.:;: n  %*<=< 2 (*�a
�a 
bibi= o  %(�`�` 0 	theauthor 	theAuthor; o      �_�_ 0 hispubs hisPubs9 >?> l //�^�]�^  �]  ? @A@ l //�\B�\  B   OPENING WINDOWS   A CDC l //�[E�[  E _ Y we can open the editor window for a publication and the information window for an author   D FGF I /6�ZH�Y
�Z .BDSKshownull��� ��� obj H o  /2�X�X 0 thepub thePub�Y  G IJI I 7>�WK�V
�W .BDSKshownull��� ��� obj K o  7:�U�U 0 	theauthor 	theAuthor�V  J LML l ??�T�S�T  �S  M NON l ??�RP�R  P   FILTERING AND SEARCHING   O QRQ l ??�QS�Q  S y s we can get and set the filter field of each document and get the list of publications that is currently displayed.   R TUT l ??�PV�P  V�� in addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.   U WXW Z  ?`YZ�O[Y = ?H\]\ 1  ?D�N
�N 
filt] m  DG^^      Z r  KT_`_ m  KNaa  	McCracken   ` 1  NS�M
�M 
filt�O  [ r  W`bcb m  WZdd      c 1  Z_�L
�L 
filtX efe e  aggg 1  ag�K
�K 
dispf hih e  hsjj I hs�J�Ik
�J .BDSKsrchlist    ��� obj �I  k �Hl�G
�H 
for l m  lomm  	McCracken   �G  i non l tt�Fp�F  p r l when writing an AppleScript for completion support in other applications use the 'for completion' parameter   o qrq e  t�ss I t��E�Dt
�E .BDSKsrchlist    ��� obj �D  t �Cuv
�C 
for u m  x{ww  	McCracken   v �Bx�A
�B 
cmplx m  ~��@
�@ savoyes �A  r y�?y l ���>�=�>  �=  �?   / o    �<�< 0 thedoc theDoc -   theDoc    + z{z l ���;�:�;  �:  { |}| l ���9~�9  ~ $  work again on the application   } � l ���8�7�8  �7  � ��� l ���6��6  � � � the search command works also at application level. It will either search every document in that case, or the one it is addressed to.   � ��� I ���5�4�
�5 .BDSKsrchlist    ��� obj �4  � �3��2
�3 
for � m  ����  	McCracken   �2  � ��� I ���1��
�1 .BDSKsrchlist    ��� obj � 4 ���0�
�0 
docu� m  ���/�/ � �.��-
�. 
for � m  ����  	McCracken   �-  � ��� l ���,��,  �  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.   � ��� O ����� r  ����� m  ����  	McCracken   � 1  ���+
�+ 
filt� 2  ���*
�* 
docu� ��� l ���)�(�)  �(  � ��� l ���'��'  �   GLOBAL PROPERTIES   � ��� l ���&��&  � 4 . you can get the folder where papers are filed   � ��� r  ����� l ����%� 1  ���$
�$ 
pfol�%  � o      �#�# "0 thepapersfolder thePapersFolder� ��� l ���"��"  � s m it is a UNIX (i.e. POSIX) style path, so if we want to use it we should translate it into a Mac style path.    � ��� O  ����� I ���!�� 
�! .aevtodocnull  �    alis� c  ����� l ����� 4  ����
� 
psxf� o  ���� "0 thepapersfolder thePapersFolder�  � m  ���
� 
alis�   � m  �����null     ߀��  �
Finder.app��� ��L��� 2����   Z ���   )       ((�K� ���0 �MACS   alis    r  Macintosh HD               ��+GH+    �
Finder.app                                                       3��K� � 0 � �����  	                CoreServices    ��'      ��/�      �  
�  
�  3Macintosh HD:System:Library:CoreServices:Finder.app    
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��  � ��� l �����  �  � ��� l �����  � %  get all known types and fields   � ��� e  ���� 1  ���
� 
atyp� ��� e  ���� 1  ���
� 
afnm� ��� l �����  �  �    m     ��null     ߀�� ��Bibdesk.appŰ� ��L��� 2����� �� ���   )       ((�K� ���  �BDSK   alis    �  Macintosh HD               ��+GH+   ��Bibdesk.app                                                     K����h        ����  	                BuildProducts     ��'      ���8     �� X� X�  !�  GMacintosh HD:Users:christiaanhofman:Documents:BuildProducts:Bibdesk.app     B i b d e s k . a p p    M a c i n t o s h   H D  :Users/christiaanhofman/Documents/BuildProducts/Bibdesk.app  /    ��  ��    ��� l     ���  �  � ��� l     ���  �  �       ����  � �
� .aevtoappnull  �   � ****� ����
���	
� .aevtoappnull  �   � ****� k    ���  
��  �  �
  �  � C��������� �� Q������������� ��������������������� ����� ��� ��� � ���������4������^ad����m��w����������������������
� .miscactvnull��� ��� null
� 
kocl
� 
docu
� .corecrel****      � null� 0 thedoc theDoc
� 
bibi
� 
insh�  �� 0 newpub newPub
�� 
BTeX�� "0 thebibtexrecord theBibTeXRecord
�� .coredelonull���     obj 
�� 
prdt�� �  
�� 
ckey�� 0 somepubs somePubs
�� 
sele
�� .BDSKsbtcnull��� ��� obj �� 0 theselection theSelection
�� 
cobj�� 0 thepub thePub
�� 
auth
�� 
aunm
�� 
lURL�� 0 thepath thePath�� 0 theurl theURL
�� 
bfld�� 0 thefield theField
�� 
fldv
�� 
pnam��  0 nonemptyfields nonEmptyFields
�� 
gcky�� 0 	theauthor 	theAuthor�� 0 hispubs hisPubs
�� .BDSKshownull��� ��� obj 
�� 
filt
�� 
disp
�� 
for 
�� .BDSKsrchlist    ��� obj 
�� 
cmpl
�� savoyes 
�� 
pfol�� "0 thepapersfolder thePapersFolder
�� 
psxf
�� 
alis
�� .aevtodocnull  �    alis
�� 
atyp
�� 
afnm�	���*j O*��l O*�k/E�O�l*���*�-6� E�O���,FO��,E�O�j O*�����l�*�-6� E�O*�-a [a ,\Za @1E` O_ *a ,FO*j O*a ,E` O_ a k/E` O_  �*a -a ,EO*a ,E` Oa E` O*a a  /E` !O*a a "/a #,EOa $*a a %/a #,FO*a -a &,E` 'O*a ,EO*a (,*a ,FO*a k/E` )O_ )a &,EOPUO*a a */EE` )O_ )�-E` +O_ j ,O_ )j ,O*a -,a .  a /*a -,FY a 0*a -,FO*a 1,EO*a 2a 3l 4O*a 2a 5a 6a 7� 4OPUO*a 2a 8l 4O*�k/a 2a 9l 4O*�- a :*a -,FUO*a ;,E` <Oa = *a >_ </a ?&j @UO*a A,EO*a B,EOPU ascr  ��ޭ