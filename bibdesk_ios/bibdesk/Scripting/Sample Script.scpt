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
for  � o   � ����� 0 theselection theSelection��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   � , & ACCESSING PROPERTIES OF A PUBLICATION    �  � � � l  �* � � � O   �* � � � k   �) � �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 1 + all properties give quite a lengthy output    �  � � � l  � ��� ���   �   get properties    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � I C plurals as well as accessing a whole array of things  work as well    �  � � � n   � � � � � 1   � ���
�� 
aunm � 2  � ���
�� 
auth �  � � � l  � �������  ��   �  � � � l  � ��� ���   � . ( as does access to the local file's path    �  � � � r   � � � � � e   � � � � 1   � ���
�� 
lURL � o      ���� 0 thepath thePath �  � � � l  � ��� ���   � Note this is a POSIX style path, unlike the value of the field "Local-URL". To use it in AppleScript, e.g. to open the file with Finder, translate it into an AppleScript style path as in the next line. AppleScript's is added because 'POSIX file' is not a Bibdesk command.    �  � � � l  � ��� ���   � &  AppleScript's POSIX file thePath    �  � � � l  � �������  ��   �  � � � l  � ��� ���   � #  we can easily set properties    �  � � � r   � � � � � m   � � � �  http://localhost/lala/    � o      ���� 0 theurl theURL �  � � � l  � �������  ��   �  � � � l  � ��� ���   � 0 * we can access all fields and their values    �  � � � r   � � � � � e   � � � � 4   � ��� �
�� 
bfld � m   � � � �  Author    � o      ���� 0 thefield theField �  � � � e   � � � � n   � � � � � 1   � ���
�� 
fldv � 4   � ��� �
�� 
bfld � m   � � � �  Title    �  � � � r   � � � � � m   � � � �  SourceForge    � n       � � � 1   � ���
�� 
fldv � 4   � ��� �
�� 
bfld � m   � �    Journal    �  l  � �������  ��    l  � ���   J D we can also get a list of all non-empty fields and their properties     r   � �	 e   � �

 n   � � 1   � ��~
�~ 
pnam 2  � ��}
�} 
bfld	 o      �|�|  0 nonemptyfields nonEmptyFields  l  � ��{�z�{  �z    l  � ��y�y    
 CITE KEYS     l  � ��x�x   8 2you can access the cite key and generate a new one     e   � 1   ��w
�w 
ckey  r   e   1  �v
�v 
gcky 1  �u
�u 
ckey  l �t�s�t  �s     l �r!�r  !   AUTHORS     "#" l �q$�q  $ 7 1 we can also query all authors in the publciation   # %&% r  '(' e  )) 4 �p*
�p 
auth* m  �o�o ( o      �n�n 0 	theauthor 	theAuthor& +,+ l �m-�m  - E ? this is the normalized name of the form 'von Last, First, Jr.'   , ./. n  '010 1  "&�l
�l 
pnam1 o  "�k�k 0 	theauthor 	theAuthor/ 2�j2 l ((�i�h�i  �h  �j   � o   � ��g�g 0 thepub thePub �   thePub    � 343 l ++�f�e�f  �e  4 565 l ++�d7�d  7 !  work again on the document   6 898 l ++�c�b�c  �b  9 :;: l ++�a<�a  <   AUTHORS   ; =>= l ++�`?�`  ? � � we can also query all authors present in the current document. To find an author by name, it is preferrable to use the (normalized) name. You can also use the 'full name' property though.   > @A@ r  +8BCB e  +4DD 4  +4�_E
�_ 
authE m  /2FF  McCracken, M.   C o      �^�^ 0 	theauthor 	theAuthorA GHG l 99�]I�]  I $  and find all his publications   H JKJ r  9CLML e  9?NN n  9?OPO 2 <>�\
�\ 
bibiP o  9<�[�[ 0 	theauthor 	theAuthorM o      �Z�Z 0 hispubs hisPubsK QRQ l DD�Y�X�Y  �X  R STS l DD�WU�W  U   OPENING WINDOWS   T VWV l DD�VX�V  X _ Y we can open the editor window for a publication and the information window for an author   W YZY I DK�U[�T
�U .BDSKshownull��� ��� obj [ o  DG�S�S 0 thepub thePub�T  Z \]\ I LS�R^�Q
�R .BDSKshownull��� ��� obj ^ o  LO�P�P 0 	theauthor 	theAuthor�Q  ] _`_ l TT�O�N�O  �N  ` aba l TT�Mc�M  c   FILTERING AND SEARCHING   b ded l TT�Lf�L  f y s we can get and set the filter field of each document and get the list of publications that is currently displayed.   e ghg l TT�Ki�K  i�� in addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.   h jkj Z  Tulm�Jnl = T]opo 1  TY�I
�I 
filtp m  Y\qq      m r  `irsr m  `ctt  	McCracken   s 1  ch�H
�H 
filt�J  n r  luuvu m  loww      v 1  ot�G
�G 
filtk xyx e  v|zz 1  v|�F
�F 
dispy {|{ e  }�}} I }��E�D~
�E .BDSKsrch****  @     obj �D  ~ �C�B
�C 
for  m  ����  	McCracken   �B  | ��� l ���A��A  � r l when writing an AppleScript for completion support in other applications use the 'for completion' parameter   � ��� l ���@��@  � 3 -get search for "McCracken" for completion yes   � ��?� l ���>�=�>  �=  �?   0 o    �<�< 0 thedoc theDoc .   theDoc    , ��� l ���;�:�;  �:  � ��� l ���9��9  � $  work again on the application   � ��� l ���8�7�8  �7  � ��� l ���6��6  � � � the search command works also at application level. It will either search every document in that case, or the one it is addressed to.   � ��� I ���5�4�
�5 .BDSKsrch****  @     obj �4  � �3��2
�3 
for � m  ����  	McCracken   �2  � ��� I ���1��
�1 .BDSKsrch****  @     obj � 4 ���0�
�0 
docu� m  ���/�/ � �.��-
�. 
for � m  ����  	McCracken   �-  � ��� l ���,��,  �  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.   � ��� O ����� r  ����� m  ����  	McCracken   � 1  ���+
�+ 
filt� 2  ���*
�* 
docu� ��� l ���)�(�)  �(  � ��� l ���'��'  �   GLOBAL PROPERTIES   � ��� l ���&��&  � 4 . you can get the folder where papers are filed   � ��� r  ����� l ����%� 1  ���$
�$ 
pfol�%  � o      �#�# "0 thepapersfolder thePapersFolder� ��� l ���"��"  � s m it is a UNIX (i.e. POSIX) style path, so if we want to use it we should translate it into a Mac style path.    � ��� O  ����� Z  �����!� � I �����
� .coredoexbool        obj � 4  ����
� 
psxf� o  ���� "0 thepapersfolder thePapersFolder�  � I �����
� .aevtodocnull  �    alis� c  ����� l ����� 4  ����
� 
psxf� o  ���� "0 thepapersfolder thePapersFolder�  � m  ���
� 
alis�  �!  �   � m  �����null     ߀��  
Finder.app��    �` �d�`���0   �`0   )       ��(�_9����`�MACS   alis    r  Macintosh HD               ���WH+    
Finder.app                                                       D1�/2�        ����  	                CoreServices    ��7      �/T        �  �  3Macintosh HD:System:Library:CoreServices:Finder.app    
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��  � ��� l �����  �  � ��� l �����  � %  get all known types and fields   � ��� e  ���� 1  ���
� 
atyp� ��� e  ���� 1  ���
� 
afnm� ��� l �����  �  �    m     ���null     ߀�� �]BibDesk.app�`   Ǚ_�l  	���p   ��� �d�`��ր #�`   ���P  BDSK   alis    �  Macintosh HD               ���WH+   �]BibDesk.app                                                     �||�6)        ����  	                Debug     ��7      ��     �] �[ �� ��  l�  CMacintosh HD:Users:hofman:Documents:BuildProducts:Debug:BibDesk.app     B i b D e s k . a p p    M a c i n t o s h   H D  6Users/hofman/Documents/BuildProducts/Debug/BibDesk.app  /    ��  ��    ��� l     ���  �  � ��� l     �
�	�
  �	  �       ����  � �
� .aevtoappnull  �   � ****� �������
� .aevtoappnull  �   � ****� k    ���  
��  �  �  �  � C��� �������������� R������������� ������������� ������������� ����� ��� ��� � ��������F������qtw�������������������������
� .miscactvnull��� ��� null
�  
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
afnm����*j O*��l O*�k/EE�O�n*���*�-6� E�O���,FO��,EE�O�j O*�����l�*�-6� E�O*�-a [a ,\Za @1E` O_ *a ,FO*a ,E` O_ a k/EE` O*a a a _ � O_  �*a -a ,EO*a ,EE` Oa  E` !O*a "a #/EE` $O*a "a %/a &,EOa '*a "a (/a &,FO*a "-a ),EE` *O*a ,EO*a +,E*a ,FO*a k/EE` ,O_ ,a ),EOPUO*a a -/EE` ,O_ ,�-EE` .O_ j /O_ ,j /O*a 0,a 1  a 2*a 0,FY a 3*a 0,FO*a 4,EO*a a 5l 6OPUO*a a 7l 6O*�k/a a 8l 6O*�- a 9*a 0,FUO*a :,E` ;Oa < %*a =_ ;/j > *a =_ ;/a ?&j @Y hUO*a A,EO*a B,EOPU ascr  ��ޭ