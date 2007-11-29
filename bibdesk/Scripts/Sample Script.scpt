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
 l     ��  O         k          l   �� ��      start BibDesk         I   	������
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
docu��        l   ������  ��       !   l   �� "��   " ; 5 get first, i.e. frontmost,  document and talk to it.    !  # $ # r     % & % e     ' ' 4   �� (
�� 
docu ( m    ����  & o      ���� 0 thedoc theDoc $  ) * ) l   ������  ��   *  + , + l  � - . - O   � / 0 / k   � 1 1  2 3 2 l   ������  ��   3  4 5 4 l   �� 6��   6 + % GENERATING AND DELETING PUBLICATIONS    5  7 8 7 l   �� 9��   9 %  make some BibTeX record to use    8  : ; : l   �� <��   < #  let's make a new publication    ;  = > = r    , ? @ ? I   *���� A
�� .corecrel****      � null��   A �� B C
�� 
kocl B m     !��
�� 
bibi C �� D��
�� 
insh D l  " & E�� E n   " & F G F  ;   % & G 2  " %��
�� 
bibi��  ��   @ o      ���� 0 newpub newPub >  H I H l  - -�� J��   J ? 9 this is initially empty, so fill it with a BibTeX string    I  K L K l  - -�� M��   M > 8 note: this can only be set before doing any other edit!    L  N O N r   - 2 P Q P m   - . R R s m@article{McCracken:2005, Author = {M. McCracken and A. Maxwell}, Title = {Working with BibDesk.},Year={2005}}    Q n       S T S 1   / 1��
�� 
BTeX T o   . /���� 0 newpub newPub O  U V U l  3 3�� W��   W + % we can get the BibTeX record as well    V  X Y X r   3 9 Z [ Z e   3 7 \ \ n   3 7 ] ^ ] 1   4 6��
�� 
BTeX ^ o   3 4���� 0 newpub newPub [ o      ���� "0 thebibtexrecord theBibTeXRecord Y  _ ` _ l  : :�� a��   a %  get rid of the new publication    `  b c b I  : ?�� d��
�� .coredelonull���     obj  d o   : ;���� 0 newpub newPub��   c  e f e l  @ @�� g��   g / ) a shortcut to creating a new publication    f  h i h r   @ S j k j I  @ Q���� l
�� .corecrel****      � null��   l �� m n
�� 
kocl m m   B C��
�� 
bibi n �� o p
�� 
prdt o K   D H q q �� r��
�� 
BTeX r o   E F���� "0 thebibtexrecord theBibTeXRecord��   p �� s��
�� 
insh s l  I M t�� t n   I M u v u  ;   L M v 2  I L��
�� 
bibi��  ��   k o      ���� 0 newpub newPub i  w x w l  T T������  ��   x  y z y l  T T�� {��   { !  MANIPULATING THE SELECTION    z  | } | l  T T�� ~��   ~ L F Play with the selection and put styled bibliography on the clipboard.    }   �  r   T j � � � l  T f ��� � 6  T f � � � 2  T W��
�� 
bibi � E   Z e � � � 1   [ _��
�� 
ckey � m   ` d � �  	McCracken   ��   � o      ���� 0 somepubs somePubs �  � � � r   k t � � � o   k n���� 0 somepubs somePubs � l      ��� � 1   n s��
�� 
sele��   �  � � � l  u u�� ���   �   get the selection    �  � � � r   u ~ � � � l  u z ��� � 1   u z��
�� 
sele��   � o      ���� 0 theselection theSelection �  � � � l   �� ���   �   and get its first item    �  � � � r    � � � � e    � � � n    � � � � 4   � ��� �
�� 
cobj � m   � �����  � o    ����� 0 theselection theSelection � o      ���� 0 thepub thePub �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 1 + get a text representation using a template    �  � � � e   � � � � I  � ����� �
�� .BDSKttxtTEXT        docu��   � �� � �
�� 
usng � m   � � � �  Default HTML template    � �� ���
�� 
for  � o   � ����� 0 theselection theSelection��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   � , & ACCESSING PROPERTIES OF A PUBLICATION    �  � � � l  �M � � � O   �M � � � k   �L � �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 1 + all properties give quite a lengthy output    �  � � � l  � ��� ���   �   get properties    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � I C plurals as well as accessing a whole array of things  work as well    �  � � � n   � � � � � 1   � ���
�� 
aunm � 2  � ���
�� 
auth �  � � � l  � �������  ��   �  � � � l  � ��� ���   � ) # as does access to the linked files    �  � � � r   � � � � � e   � � � � 2  � ���
�� 
File � o      ���� 0 thefiles theFiles �  � � � l  � ��� ���   � � � Note this is an array of file objects which can be 'missing value' when the file was not found. You can get the POSIX path of a linked file or the URL as a string. In the latter case you need to get the URL of a reference.    �  � � � l  � ��� ���   �  POSIX path of theFiles    �  � � � l  � ��� ���   �  URL of linked file 1    �  � � � l  � �������  ��   �  � � � l  � ��� ���   �   and the linked URLs    �  � � � r   � � � � � 2  � ���
�� 
URL  � o      ���� 0 theurls theURLs �  � � � l  � �������  ��   �  � � � l  � ��� ���   � #  we can easily set properties    �  � � � r   � � � � � m   � � � �  Working with BibDesk.    � 1   � ���
�� 
titl �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 0 * we can access all fields and their values    �  � � � r   � � � � � e   � � � � 4   � ��� �
�� 
bfld � m   � � � �  Author    � o      ���� 0 thefield theField �  � � � e   � � � � n   � �   1   � ��
� 
fldv 4   � ��~
�~ 
bfld m   � �  Title    �  r   � � m   � �  SourceForge    n      	
	 1   � ��}
�} 
fldv
 4   � ��|
�| 
bfld m   � �  Journal     l  � ��{�z�{  �z    l  � ��y�y   J D we can also get a list of all non-empty fields and their properties     r   �
 e   � n   � 1  �x
�x 
pnam 2  ��w
�w 
bfld o      �v�v  0 nonemptyfields nonEmptyFields  l �u�t�u  �t    l �s�s    
 CITE KEYS     l �r �r    9 3 you can access the cite key and generate a new one    !"! e  ## 1  �q
�q 
ckey" $%$ r  &'& e  (( 1  �p
�p 
gcky' 1  �o
�o 
ckey% )*) l �n�m�n  �m  * +,+ l �l-�l  -   AUTHORS   , ./. l �k0�k  0 7 1 we can also query all authors in the publciation   / 121 r  *343 e  &55 4 &�j6
�j 
auth6 m  #$�i�i 4 o      �h�h 0 	theauthor 	theAuthor2 787 l ++�g9�g  9 E ? this is the normalized name of the form 'von Last, First, Jr.'   8 :;: n  +3<=< 1  .2�f
�f 
pnam= o  +.�e�e 0 	theauthor 	theAuthor; >?> l 44�d�c�d  �c  ? @A@ l 44�bB�b  B   LINKED FILES and URLs   A CDC l 44�aE�a  E > 8 creating new linked files and URLs is a bit unintuitive   D FGF I 4J�`�_H
�` .corecrel****      � null�_  H �^IJ
�^ 
koclI m  69�]
�] 
URL J �\KL
�\ 
dataK m  <?MM  http://myhost/foo/bar   L �[N�Z
�[ 
inshN n  @FOPO  ;  EFP 2 @E�Y
�Y 
URL �Z  G QRQ l KK�XS�X  S a [make new linked file with data (POSIX file "/path/to/my/file") at beginning of linked files   R T�WT l KK�V�U�V  �U  �W   � o   � ��T�T 0 thepub thePub �   thePub    � UVU l NN�S�R�S  �R  V WXW l NN�QY�Q  Y !  work again on the document   X Z[Z l NN�P�O�P  �O  [ \]\ l NN�N^�N  ^   AUTHORS   ] _`_ l NN�Ma�M  a � � we can also query all authors present in the current document. To find an author by name, it is preferrable to use the (normalized) name. You can also use the 'full name' property though.   ` bcb r  N[ded e  NWff 4  NW�Lg
�L 
authg m  RUhh  McCracken, M.   e o      �K�K 0 	theauthor 	theAuthorc iji l \\�Jk�J  k $  and find all his publications   j lml r  \fnon e  \bpp n  \bqrq 2 _a�I
�I 
bibir o  \_�H�H 0 	theauthor 	theAuthoro o      �G�G 0 hispubs hisPubsm sts l gg�F�E�F  �E  t uvu l gg�Dw�D  w   OPENING WINDOWS   v xyx l gg�Cz�C  z _ Y we can open the editor window for a publication and the information window for an author   y {|{ I gn�B}�A
�B .BDSKshownull��� ��� obj } o  gj�@�@ 0 thepub thePub�A  | ~~ I ov�?��>
�? .BDSKshownull��� ��� obj � o  or�=�= 0 	theauthor 	theAuthor�>   ��� l ww�<�;�<  �;  � ��� l ww�:��:  �   FILTERING AND SEARCHING   � ��� l ww�9��9  � y s we can get and set the filter field of each document and get the list of publications that is currently displayed.   � ��� l ww�8��8  ��� in addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.   � ��� Z  w����7�� = w���� 1  w|�6
�6 
filt� m  |��      � r  ����� m  ����  	McCracken   � 1  ���5
�5 
filt�7  � r  ����� m  ����      � 1  ���4
�4 
filt� ��� e  ���� 1  ���3
�3 
disp� ��� e  ���� I ���2�1�
�2 .BDSKsrch****  @     obj �1  � �0��/
�0 
for � m  ����  	McCracken   �/  � ��� l ���.��.  � r l when writing an AppleScript for completion support in other applications use the 'for completion' parameter   � ��� l ���-��-  � 3 -get search for "McCracken" for completion yes   � ��,� l ���+�*�+  �*  �,   0 o    �)�) 0 thedoc theDoc .   theDoc    , ��� l ���(�'�(  �'  � ��� l ���&��&  � $  work again on the application   � ��� l ���%�$�%  �$  � ��� l ���#��#  � � � the search command works also at application level. It will either search every document in that case, or the one it is addressed to.   � ��� I ���"�!�
�" .BDSKsrch****  @     obj �!  � � ��
�  
for � m  ����  	McCracken   �  � ��� I �����
� .BDSKsrch****  @     obj � 4 ����
� 
docu� m  ���� � ���
� 
for � m  ����  	McCracken   �  � ��� l �����  �  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.   � ��� O ����� r  ����� m  ����  	McCracken   � 1  ���
� 
filt� 2  ���
� 
docu� ��� l �����  �  � ��� l �����  �   GLOBAL PROPERTIES   � ��� l �����  � 4 . you can get the folder where papers are filed   � ��� r  ����� l ����� 1  ���
� 
pfol�  � o      �� "0 thepapersfolder thePapersFolder� ��� l �����  � s m it is a UNIX (i.e. POSIX) style path, so if we want to use it we should translate it into a Mac style path.    � ��� O  ���� Z  ������ I �����
� .coredoexbool        obj � 4  ���
�
�
 
psxf� o  ���	�	 "0 thepapersfolder thePapersFolder�  � I �
���
� .aevtodocnull  �    alis� c  ���� l ���� 4  ���
� 
psxf� o  ��� "0 thepapersfolder thePapersFolder�  � m  �
� 
alis�  �  �  � m  �����null     ߀��  
Finder.app�ː    ��� ��N`��˰   /P0   )       �(��������BMACS   alis    r  Macintosh HD               ��GH+    
Finder.app                                                       D1�/$t        ����  	                CoreServices    ��7      �/T        �  �  3Macintosh HD:System:Library:CoreServices:Finder.app    
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��  � ��� l ���  �  � ��� l � ��   � %  get all known types and fields   � ��� e  �� 1  ��
�� 
atyp� ��� e  �� 1  ��
�� 
afnm� ���� l ������  ��  ��    m     ���null     ߀�� �]BibDesk.app    �� b����   �� c<�+�    7Y�7�̠ h�Bnt�zBDSK   alis    �  Macintosh HD               ��GH+   �]BibDesk.app                                                    %��g��        ����  	                Debug     ��7      �g��     �] �[ �w ��  l�  EMacintosh HD:Users:hofman:Development:BuildProducts:Debug:BibDesk.app     B i b D e s k . a p p    M a c i n t o s h   H D  8Users/hofman/Development/BuildProducts/Debug/BibDesk.app  /    ��  ��    ��� l     ������  ��  � ���� l     ������  ��  ��       ������  � ��
�� .aevtoappnull  �   � ****� �����������
�� .aevtoappnull  �   � ****� k     ��  
����  ��  ��  �  � G������������������� R������������� ������������� ����������������� ����� ���������������Mh����������������������������������
�� .miscactvnull��� ��� null
�� 
kocl
�� 
docu
�� .corecrel****      � null�� 0 thedoc theDoc
�� 
bibi
�� 
insh�� �� 0 newpub newPub
�� 
BTeX�� "0 thebibtexrecord theBibTeXRecord
�� .coredelonull���     obj 
�� 
prdt�� �  
�� 
ckey�� 0 somepubs somePubs
�� 
sele�� 0 theselection theSelection
�� 
cobj�� 0 thepub thePub
�� 
usng
�� 
for 
�� .BDSKttxtTEXT        docu
�� 
auth
�� 
aunm
�� 
File�� 0 thefiles theFiles
�� 
URL �� 0 theurls theURLs
�� 
titl
�� 
bfld�� 0 thefield theField
�� 
fldv
�� 
pnam��  0 nonemptyfields nonEmptyFields
�� 
gcky�� 0 	theauthor 	theAuthor
�� 
data�� 0 hispubs hisPubs
�� .BDSKshownull��� ��� obj 
�� 
filt
�� 
disp
�� .BDSKsrch****  @     obj 
�� 
pfol�� "0 thepapersfolder thePapersFolder
�� 
psxf
�� .coredoexbool        obj 
�� 
alis
�� .aevtodocnull  �    alis
�� 
atyp
�� 
afnm��!�*j O*��l O*�k/EE�O��*���*�-6� E�O���,FO��,EE�O�j O*�����l�*�-6� E�O*�-a [a ,\Za @1E` O_ *a ,FO*a ,E` O_ a k/EE` O*a a a _ � O_  �*a -a ,EO*a -EE` O*a  -E` !Oa "*a #,FO*a $a %/EE` &O*a $a '/a (,EOa )*a $a */a (,FO*a $-a +,EE` ,O*a ,EO*a -,E*a ,FO*a k/EE` .O_ .a +,EO*�a  a /a 0�*a  -6� OPUO*a a 1/EE` .O_ .�-EE` 2O_ j 3O_ .j 3O*a 4,a 5  a 6*a 4,FY a 7*a 4,FO*a 8,EO*a a 9l :OPUO*a a ;l :O*�k/a a <l :O*�- a =*a 4,FUO*a >,E` ?Oa @ %*a A_ ?/j B *a A_ ?/a C&j DY hUO*a E,EO*a F,EOPU ascr  ��ޭ