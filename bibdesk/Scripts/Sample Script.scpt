FasdUAS 1.101.10   ��   ��    k             l      ��  ��   ��
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
     � 	 	
 
 T h i s   i s   a   s a m p l e   s c r i p t   t o   s h o w   A p p l e S c r i p t   s u p p o r t   f o r   B i b D e s k .   
 W h e n   y o u   r u n   t h i s   s c r i p t ,   i t   c r e a t e s   a   n e w   d o c u m e n t .   S o   a n y   
 c u r r e n t l y   o p e n e d   d o c u m e n t   i n   B i b d e s k   s h o u l d   n o t   b e   a f f e c t e d . 
 
 I f   y o u   w a n t   t o   i n s p e c t   t h e   r e t u r n   v a l u e   o f   a   p a r t i c u l a r   
 l i n e   i n   t h i s   s c r i p t ,   i n s e r t   ' r e t u r n   r e s u l t '   a f t e r   t h a t   l i n e   
 a n d   r u n   t h e   s c r i p t .   
 
 Y o u   c a n   i n s p e c t   t h e   s u p p o r t e d   c l a s s e s   a n d   c o m m a n d s   
 i n   t h e   A p p l e S c r i p t   l i b r a r y .   I n   t h e   S c r i p t   E d i t o r ,   c h o o s e   
 F i l e   >   O p e n   D i c t i o n a r y & ,   o r   S h i f t - C o m m a n d - O ,   a n d   
 s e l e c t   B i b d e s k .   
 
 F o r   m o r e   i n f o r m a t i o n   a b o u t   B i b D e s k ,   i n c l u d i n g   a   c o l l e c t i o n   o f 
 A p p l e S c r i p t s ,   s e e   t h e   B i b d e s k   h o m e   p a g e   a t   
 h t t p : / / b i b d e s k . s o u r g e f o r g e . n e t 
   
  
 l     ��������  ��  ��        l   ~ ����  O    ~    k   }       l   ��  ��      start BibDesk     �      s t a r t   B i b D e s k      I   	������
�� .miscactvnull��� ��� null��  ��        l  
 
��������  ��  ��        l  
 
��  ��       and create a new document     �   4   a n d   c r e a t e   a   n e w   d o c u m e n t     !   I  
 ���� "
�� .corecrel****      � null��   " �� #��
�� 
kocl # m    ��
�� 
docu��   !  $ % $ l   ��������  ��  ��   %  & ' & l   �� ( )��   ( ; 5 get first, i.e. frontmost,  document and talk to it.    ) � * * j   g e t   f i r s t ,   i . e .   f r o n t m o s t ,     d o c u m e n t   a n d   t a l k   t o   i t . '  + , + r     - . - e     / / 4   �� 0
�� 
docu 0 m    ����  . o      ���� 0 thedoc theDoc ,  1 2 1 l   ��������  ��  ��   2  3 4 3 l   5 6 7 5 O    8 9 8 k    : :  ; < ; l   ��������  ��  ��   <  = > = l   �� ? @��   ? + % GENERATING AND DELETING PUBLICATIONS    @ � A A J   G E N E R A T I N G   A N D   D E L E T I N G   P U B L I C A T I O N S >  B C B l   �� D E��   D ) # let's make a new empty publication    E � F F F   l e t ' s   m a k e   a   n e w   e m p t y   p u b l i c a t i o n C  G H G r    , I J I I   *���� K
�� .corecrel****      � null��   K �� L M
�� 
kocl L m     !��
�� 
bibi M �� N��
�� 
insh N l  " & O���� O n   " & P Q P  :   % & Q 2  " %��
�� 
bibi��  ��  ��   J o      ���� 0 newpub newPub H  R S R l  - -�� T U��   T "  make a copy of the new item    U � V V 8   m a k e   a   c o p y   o f   t h e   n e w   i t e m S  W X W r   - 9 Y Z Y I  - 7�� [ \
�� .coreclon****      � **** [ o   - .���� 0 newpub newPub \ �� ]��
�� 
insh ] n   / 3 ^ _ ^  ;   2 3 _ 2  / 2��
�� 
bibi��   Z o      ���� 0 newpub newPub X  ` a ` l  : :�� b c��   b %  get rid of the new publication    c � d d >   g e t   r i d   o f   t h e   n e w   p u b l i c a t i o n a  e f e I  : ?�� g��
�� .coredelonull���     obj  g o   : ;���� 0 newpub newPub��   f  h i h l  @ @�� j k��   j "  get rid of all publications    k � l l 8   g e t   r i d   o f   a l l   p u b l i c a t i o n s i  m n m I  @ G�� o��
�� .coredelonull���     obj  o 2  @ C��
�� 
bibi��   n  p q p l  H H�� r s��   r %  make some BibTeX record to use    s � t t >   m a k e   s o m e   B i b T e X   r e c o r d   t o   u s e q  u v u r   H K w x w m   H I y y � z z � @ a r t i c l e { M c C r a c k e n : 2 0 0 5 ,   A u t h o r   =   { M .   M c C r a c k e n   a n d   A .   M a x w e l l } ,   T i t l e   =   { W o r k i n g   w i t h   B i b D e s k . } , Y e a r = { 2 0 0 5 } } x o      ���� "0 thebibtexrecord theBibTeXRecord v  { | { l  L L�� } ~��   } 9 3 now make a new publication with this BibTeX string    ~ �   f   n o w   m a k e   a   n e w   p u b l i c a t i o n   w i t h   t h i s   B i b T e X   s t r i n g |  � � � l  L L�� � ���   � K E note: the BibTeX string can only be set before doing any other edit!    � � � � �   n o t e :   t h e   B i b T e X   s t r i n g   c a n   o n l y   b e   s e t   b e f o r e   d o i n g   a n y   o t h e r   e d i t ! �  � � � r   L a � � � I  L _���� �
�� .corecrel****      � null��   � �� � �
�� 
kocl � m   N O��
�� 
bibi � �� � �
�� 
prdt � K   P T � � �� ���
�� 
BTeX � o   Q R���� "0 thebibtexrecord theBibTeXRecord��   � �� ���
�� 
insh � l  U Y ����� � n   U Y � � �  :   X Y � 2  U X��
�� 
bibi��  ��  ��   � o      ���� 0 newpub newPub �  � � � l  b b�� � ���   � + % we can get the BibTeX record as well    � � � � J   w e   c a n   g e t   t h e   B i b T e X   r e c o r d   a s   w e l l �  � � � r   b h � � � e   b f � � n   b f � � � 1   c e��
�� 
BTeX � o   b c���� 0 newpub newPub � o      ���� "0 thebibtexrecord theBibTeXRecord �  � � � l  i i�� � ���   � / ) a shortcut to creating a new publication    � � � � R   a   s h o r t c u t   t o   c r e a t i n g   a   n e w   p u b l i c a t i o n �  � � � r   i ~ � � � I  i |���� �
�� .corecrel****      � null��   � �� � �
�� 
kocl � m   k l��
�� 
bibi � �� � �
�� 
prdt � K   m q � � �� ���
�� 
BTeX � o   n o���� "0 thebibtexrecord theBibTeXRecord��   � �� ���
�� 
insh � l  r v ����� � n   r v � � �  ;   u v � 2  r u��
�� 
bibi��  ��  ��   � o      ���� 0 newpub newPub �  � � � l   ��������  ��  ��   �  � � � l   �� � ���   � !  MANIPULATING THE SELECTION    � � � � 6   M A N I P U L A T I N G   T H E   S E L E C T I O N �  � � � l   �� � ���   � L F Play with the selection and put styled bibliography on the clipboard.    � � � � �   P l a y   w i t h   t h e   s e l e c t i o n   a n d   p u t   s t y l e d   b i b l i o g r a p h y   o n   t h e   c l i p b o a r d . �  � � � r    � � � � l   � ����� � 6   � � � � 2   ���
�� 
bibi � E   � � � � � 1   � ���
�� 
ckey � m   � � � � � � �  M c C r a c k e n��  ��   � o      ���� 0 somepubs somePubs �  � � � r   � � � � � o   � ����� 0 somepubs somePubs � l      ����� � 1   � ���
�� 
sele��  ��   �  � � � l  � ��� � ���   �   get the selection    � � � � $   g e t   t h e   s e l e c t i o n �  � � � r   � � � � � l  � � ����� � 1   � ���
�� 
sele��  ��   � o      ���� 0 theselection theSelection �  � � � l  � ��� � ���   �   and get its first item    � � � � .   a n d   g e t   i t s   f i r s t   i t e m �  � � � r   � � � � � e   � � � � n   � � � � � 4   � ��� �
�� 
cobj � m   � �����  � o   � ����� 0 theselection theSelection � o      ���� 0 thepub thePub �  � � � l  � ���������  ��  ��   �  � � � l  � ��� � ���   � 1 + get a text representation using a template    � � � � V   g e t   a   t e x t   r e p r e s e n t a t i o n   u s i n g   a   t e m p l a t e �  � � � e   � � � � I  � ����� �
�� .BDSKttxtTEXT        docu��   � �� � �
�� 
usng � m   � � � � � � � * D e f a u l t   H T M L   t e m p l a t e � � ��~
� 
for  � o   � ��}�} 0 theselection theSelection�~   �  � � � l  � ��|�{�z�|  �{  �z   �  � � � l  � ��y � ��y   �   GROUPS    � � � �    G R O U P S �  � � � l  � ��x �x      make a new static group    � 0   m a k e   a   n e w   s t a t i c   g r o u p �  r   � � I  � ��w�v
�w .corecrel****      � null�v   �u	
�u 
kocl m   � ��t
�t 
StGp	 �s
�r
�s 
prdt
 K   � � �q�p
�q 
pnam m   � � �  S t a t i c   G r o u p�p  �r   o      �o�o 0 thegroup theGroup  l  � ��n�n   E ? add our item to the group, you cannot add to an external group    � ~   a d d   o u r   i t e m   t o   t h e   g r o u p ,   y o u   c a n n o t   a d d   t o   a n   e x t e r n a l   g r o u p  I  � ��m
�m .BDSKAdd null���     **** o   � ��l�l 0 thepub thePub �k�j
�k 
insh o   � ��i�i 0 thegroup theGroup�j    l  � ��h�h     and remove it again    � (   a n d   r e m o v e   i t   a g a i n  I  � ��g !
�g .BDSKRemvnull���     ****  o   � ��f�f 0 thepub thePub! �e"�d
�e 
from" o   � ��c�c 0 thegroup theGroup�d   #$# l  � ��b%&�b  % R L groups are always to-many relationships, even if there is only a single one   & �'' �   g r o u p s   a r e   a l w a y s   t o - m a n y   r e l a t i o n s h i p s ,   e v e n   i f   t h e r e   i s   o n l y   a   s i n g l e   o n e$ ()( l  �*�a�`* n   �+,+ 2 �_
�_ 
bibi, 4   ��^-
�^ 
Libr- m   � �]�] �a  �`  ) ./. l �\�[�Z�\  �[  �Z  / 010 l �Y23�Y  2 , & ACCESSING PROPERTIES OF A PUBLICATION   3 �44 L   A C C E S S I N G   P R O P E R T I E S   O F   A   P U B L I C A T I O N1 565 l �7897 O  �:;: k  �<< =>= l �X�W�V�X  �W  �V  > ?@? l �UAB�U  A 1 + all properties give quite a lengthy output   B �CC V   a l l   p r o p e r t i e s   g i v e   q u i t e   a   l e n g t h y   o u t p u t@ DED l �TFG�T  F   get properties   G �HH    g e t   p r o p e r t i e sE IJI l �S�R�Q�S  �R  �Q  J KLK l �PMN�P  M I C plurals as well as accessing a whole array of things  work as well   N �OO �   p l u r a l s   a s   w e l l   a s   a c c e s s i n g   a   w h o l e   a r r a y   o f   t h i n g s     w o r k   a s   w e l lL PQP n  RSR 1  �O
�O 
aunmS 2 �N
�N 
authQ TUT l �M�L�K�M  �L  �K  U VWV l �JXY�J  X ) # as does access to the linked files   Y �ZZ F   a s   d o e s   a c c e s s   t o   t h e   l i n k e d   f i l e sW [\[ r   ]^] e  __ 2 �I
�I 
File^ o      �H�H 0 thefiles theFiles\ `a` l !!�Gbc�G  b � � Note this is an array of file objects which can be 'missing value' when the file was not found. You can get the POSIX path of a linked file or the URL as a string. In the latter case you need to get the URL of a reference.   c �dd�   N o t e   t h i s   i s   a n   a r r a y   o f   f i l e   o b j e c t s   w h i c h   c a n   b e   ' m i s s i n g   v a l u e '   w h e n   t h e   f i l e   w a s   n o t   f o u n d .   Y o u   c a n   g e t   t h e   P O S I X   p a t h   o f   a   l i n k e d   f i l e   o r   t h e   U R L   a s   a   s t r i n g .   I n   t h e   l a t t e r   c a s e   y o u   n e e d   t o   g e t   t h e   U R L   o f   a   r e f e r e n c e .a efe l !!�Fgh�F  g  POSIX path of theFiles   h �ii , P O S I X   p a t h   o f   t h e F i l e sf jkj l !!�Elm�E  l  URL of linked file 1   m �nn ( U R L   o f   l i n k e d   f i l e   1k opo l !!�D�C�B�D  �C  �B  p qrq l !!�Ast�A  s   and the linked URLs   t �uu (   a n d   t h e   l i n k e d   U R L sr vwv r  !*xyx 2 !&�@
�@ 
URL y o      �?�? 0 theurls theURLsw z{z l ++�>�=�<�>  �=  �<  { |}| l ++�;~�;  ~ #  we can easily set properties    ��� :   w e   c a n   e a s i l y   s e t   p r o p e r t i e s} ��� r  +4��� m  +.�� ��� * W o r k i n g   w i t h   B i b D e s k .� 1  .3�:
�: 
titl� ��� l 55�9�8�7�9  �8  �7  � ��� l 55�6���6  � 0 * we can access all fields and their values   � ��� T   w e   c a n   a c c e s s   a l l   f i e l d s   a n d   t h e i r   v a l u e s� ��� r  5B��� e  5>�� 4  5>�5�
�5 
bfld� m  9<�� ���  A u t h o r� o      �4�4 0 thefield theField� ��� e  CP�� n  CP��� 1  KO�3
�3 
fldv� 4  CK�2�
�2 
bfld� m  GJ�� ��� 
 T i t l e� ��� r  Qa��� m  QT�� ���  S o u r c e F o r g e� n      ��� 1  \`�1
�1 
fldv� 4  T\�0�
�0 
bfld� m  X[�� ���  J o u r n a l� ��� l bb�/�.�-�/  �.  �-  � ��� l bb�,���,  � J D we can also get a list of all non-empty fields and their properties   � ��� �   w e   c a n   a l s o   g e t   a   l i s t   o f   a l l   n o n - e m p t y   f i e l d s   a n d   t h e i r   p r o p e r t i e s� ��� r  bp��� e  bl�� n  bl��� 1  gk�+
�+ 
pnam� 2 bg�*
�* 
bfld� o      �)�)  0 nonemptyfields nonEmptyFields� ��� l qq�(�'�&�(  �'  �&  � ��� l qq�%���%  �  
 CITE KEYS   � ���    C I T E   K E Y S� ��� l qq�$���$  � 9 3 you can access the cite key and generate a new one   � ��� f   y o u   c a n   a c c e s s   t h e   c i t e   k e y   a n d   g e n e r a t e   a   n e w   o n e� ��� e  qw�� 1  qw�#
�# 
ckey� ��� r  x���� e  x~�� 1  x~�"
�" 
gcky� 1  ~��!
�! 
ckey� ��� l ��� ���   �  �  � ��� l ������  �   AUTHORS   � ���    A U T H O R S� ��� l ������  � 7 1 we can also query all authors in the publciation   � ��� b   w e   c a n   a l s o   q u e r y   a l l   a u t h o r s   i n   t h e   p u b l c i a t i o n� ��� r  ����� e  ���� 4 ����
� 
auth� m  ���� � o      �� 0 	theauthor 	theAuthor� ��� l ������  � E ? this is the normalized name of the form 'von Last, First, Jr.'   � ��� ~   t h i s   i s   t h e   n o r m a l i z e d   n a m e   o f   t h e   f o r m   ' v o n   L a s t ,   F i r s t ,   J r . '� ��� n  ����� 1  ���
� 
pnam� o  ���� 0 	theauthor 	theAuthor� ��� l ������  �  �  � ��� l ������  �   LINKED FILES and URLs   � ��� ,   L I N K E D   F I L E S   a n d   U R L s� ��� l ������  �   add a new linked URL   � ��� *   a d d   a   n e w   l i n k e d   U R L� ��� I �����
� .BDSKAdd null���     ****� m  ���� ��� * h t t p : / / m y h o s t / f o o / b a r� ���
� 
insh� n  �����  ;  ��� 2 ���
� 
URL �  � ��� l ������  � F @add (POSIX file "/path/to/my/file") to beginning of linked files   � ��� � a d d   ( P O S I X   f i l e   " / p a t h / t o / m y / f i l e " )   t o   b e g i n n i n g   o f   l i n k e d   f i l e s�  �  l ���
�	��
  �	  �  �  ; o  �� 0 thepub thePub8   thePub   9 �    t h e P u b6  l ������  �  �    l ����   !  work again on the document    � 6   w o r k   a g a i n   o n   t h e   d o c u m e n t 	
	 l ����� �  �  �   
  l ������     AUTHORS    �    A U T H O R S  l ������   � � we can also query all authors present in the current document. To find an author by name, it is preferrable to use the (normalized) name. You can also use the 'full name' property though.    �x   w e   c a n   a l s o   q u e r y   a l l   a u t h o r s   p r e s e n t   i n   t h e   c u r r e n t   d o c u m e n t .   T o   f i n d   a n   a u t h o r   b y   n a m e ,   i t   i s   p r e f e r r a b l e   t o   u s e   t h e   ( n o r m a l i z e d )   n a m e .   Y o u   c a n   a l s o   u s e   t h e   ' f u l l   n a m e '   p r o p e r t y   t h o u g h .  r  �� e  �� 4  ����
�� 
auth m  �� �  M c C r a c k e n ,   M . o      ���� 0 	theauthor 	theAuthor  l ���� ��   $  and find all his publications     �!! <   a n d   f i n d   a l l   h i s   p u b l i c a t i o n s "#" r  ��$%$ e  ��&& n  ��'(' 2 ����
�� 
bibi( o  ������ 0 	theauthor 	theAuthor% o      ���� 0 hispubs hisPubs# )*) l ����������  ��  ��  * +,+ l ����-.��  -   OPENING WINDOWS   . �//     O P E N I N G   W I N D O W S, 010 l ����23��  2 _ Y we can open the editor window for a publication and the information window for an author   3 �44 �   w e   c a n   o p e n   t h e   e d i t o r   w i n d o w   f o r   a   p u b l i c a t i o n   a n d   t h e   i n f o r m a t i o n   w i n d o w   f o r   a n   a u t h o r1 565 I ����7��
�� .BDSKshownull��� ��� obj 7 o  ������ 0 thepub thePub��  6 898 I ����:��
�� .BDSKshownull��� ��� obj : o  ������ 0 	theauthor 	theAuthor��  9 ;<; l ����������  ��  ��  < =>= l ����?@��  ?   FILTERING AND SEARCHING   @ �AA 0   F I L T E R I N G   A N D   S E A R C H I N G> BCB l ����DE��  D y s we can get and set the filter field of each document and get the list of publications that is currently displayed.   E �FF �   w e   c a n   g e t   a n d   s e t   t h e   f i l t e r   f i e l d   o f   e a c h   d o c u m e n t   a n d   g e t   t h e   l i s t   o f   p u b l i c a t i o n s   t h a t   i s   c u r r e n t l y   d i s p l a y e d .C GHG l ����IJ��  I�� in addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.   J �KK2   i n   a d d i t i o n   t h e r e   i s   t h e   s e a r c h   c o m m a n d   w h i c h   r e t u r n s   t h e   r e s u l t s   o f   a   s e a r c h .   T h a t   s e a r c h   m a t c h e s   o n l y   t h e   c i t e   k e y ,   t h e   a u t h o r s '   s u r n a m e s   a n d   t h e   p u b l i c a t i o n ' s   t i t l e .   W a r n i n g :   i t s   r e s u l t s   m a y   b e   d i f f e r e n t   f r o m   w h a t ' s   s e e n   w h e n   u s i n g   t h e   f i l t e r   f i e l d   f o r   t h e   s a m e   t e r m .   I t   i s   m a i n l y   i n t e n d e d   f o r   a u t o c o m p l e t i o n   u s e   a n d   u s i n g   ' w h o s e '   s t a t e m e n t s   t o   s e a r c h   f o r   p u b l i c a t i o n s   s h o u l d   b e   m o r e   p o w e r f u l ,   b u t   s l o w e r .H LML Z  ��NO��PN = ��QRQ 1  ����
�� 
filtR m  ��SS �TT  O r  ��UVU m  ��WW �XX  M c C r a c k e nV 1  ����
�� 
filt��  P r  ��YZY m  ��[[ �\\  Z 1  ����
�� 
filtM ]^] e  ��__ 1  ����
�� 
disp^ `a` e  �	bb I �	����c
�� .BDSKsrch****  @     obj ��  c ��d��
�� 
for d m  ee �ff  M c C r a c k e n��  a ghg l 

��ij��  i r l when writing an AppleScript for completion support in other applications use the 'for completion' parameter   j �kk �   w h e n   w r i t i n g   a n   A p p l e S c r i p t   f o r   c o m p l e t i o n   s u p p o r t   i n   o t h e r   a p p l i c a t i o n s   u s e   t h e   ' f o r   c o m p l e t i o n '   p a r a m e t e rh lml l 

��no��  n 3 -get search for "McCracken" for completion yes   o �pp Z g e t   s e a r c h   f o r   " M c C r a c k e n "   f o r   c o m p l e t i o n   y e sm q��q l 

��������  ��  ��  ��   9 o    ���� 0 thedoc theDoc 6   theDoc    7 �rr    t h e D o c 4 sts l ��������  ��  ��  t uvu l ��wx��  w $  work again on the application   x �yy <   w o r k   a g a i n   o n   t h e   a p p l i c a t i o nv z{z l ��������  ��  ��  { |}| l ��~��  ~ � � the search command works also at application level. It will either search every document in that case, or the one it is addressed to.    ���   t h e   s e a r c h   c o m m a n d   w o r k s   a l s o   a t   a p p l i c a t i o n   l e v e l .   I t   w i l l   e i t h e r   s e a r c h   e v e r y   d o c u m e n t   i n   t h a t   c a s e ,   o r   t h e   o n e   i t   i s   a d d r e s s e d   t o .} ��� I �����
�� .BDSKsrch****  @     obj ��  � �����
�� 
for � m  �� ���  M c C r a c k e n��  � ��� I '����
�� .BDSKsrch****  @     obj � 4 ���
�� 
docu� m  ���� � �����
�� 
for � m   #�� ���  M c C r a c k e n��  � ��� l ((������  �  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.   � ��� �   A p p l e S c r i p t   l e t s   u s   e a s i l y   s e t   t h e   f i l t e r   f i e l d   i n   a l l   o p e n   d o c u m e n t s .   T h i s   i s   u s e d   i n   t h e   L a u n c h B a r   i n t e g r a t i o n   s c r i p t .� ��� O (8��� r  .7��� m  .1�� ���  M c C r a c k e n� 1  16��
�� 
filt� 2  (+��
�� 
docu� ��� l 99��������  ��  ��  � ��� l 99������  �   GLOBAL PROPERTIES   � ��� $   G L O B A L   P R O P E R T I E S� ��� l 99������  � 4 . you can get the folder where papers are filed   � ��� \   y o u   c a n   g e t   t h e   f o l d e r   w h e r e   p a p e r s   a r e   f i l e d� ��� r  9B��� l 9>������ 1  9>��
�� 
pfol��  ��  � o      ���� "0 thepapersfolder thePapersFolder� ��� l CC������  � s m it is a UNIX (i.e. POSIX) style path, so if we want to use it we should translate it into a Mac style path.    � ��� �   i t   i s   a   U N I X   ( i . e .   P O S I X )   s t y l e   p a t h ,   s o   i f   w e   w a n t   t o   u s e   i t   w e   s h o u l d   t r a n s l a t e   i t   i n t o   a   M a c   s t y l e   p a t h .  � ��� O  Cm��� Z  Il������� I IU�����
�� .coredoexbool        obj � 4  IQ���
�� 
psxf� o  MP���� "0 thepapersfolder thePapersFolder��  � I Xh�����
�� .aevtodocnull  �    alis� c  Xd��� l X`������ 4  X`���
�� 
psxf� o  \_���� "0 thepapersfolder thePapersFolder��  ��  � m  `c��
�� 
alis��  ��  ��  � m  CF���                                                                                  MACS   alis    r  Macintosh HD               ��GH+  @PF
Finder.app                                                     @Á�0�4        ����  	                CoreServices    ��7      �0�    @PF@P@P  3Macintosh HD:System:Library:CoreServices:Finder.app    
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��  � ��� l nn��������  ��  ��  � ��� l nn������  � %  get all known types and fields   � ��� >   g e t   a l l   k n o w n   t y p e s   a n d   f i e l d s� ��� e  nt�� 1  nt��
�� 
atyp� ��� e  u{�� 1  u{��
�� 
afnm� ���� l ||��������  ��  ��  ��    m     ���                                                                                  BDSK   alis    �  Macintosh HD               ��GH+  I6LBibDesk.app                                                    �/,��pj        ����  	                Debug     ��7      ��bZ    I6LI6KI�IO@�7  EMacintosh HD:Users:hofman:Development:BuildProducts:Debug:BibDesk.app     B i b D e s k . a p p    M a c i n t o s h   H D  8Users/hofman/Development/BuildProducts/Debug/BibDesk.app  /    ��  ��  ��    ��� l     ��������  ��  ��  � ���� l     ��������  ��  ��  ��       ������  � ��
�� .aevtoappnull  �   � ****� �����������
�� .aevtoappnull  �   � ****� k    ~��  ����  ��  ��  �  � N����������������������� y����������� �����������~ ��}�|�{�z�y�x�w�v�u�t�s�r�q�p�o��n�m��l��k���j�i�h��g�f�eSW[�de�c����b�a��`�_�^�]�\�[
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
�� .coreclon****      � ****
�� .coredelonull���     obj �� "0 thebibtexrecord theBibTeXRecord
�� 
prdt
�� 
BTeX�� �  
�� 
ckey�� 0 somepubs somePubs
�� 
sele�� 0 theselection theSelection
�� 
cobj� 0 thepub thePub
�~ 
usng
�} 
for 
�| .BDSKttxtTEXT        docu
�{ 
StGp
�z 
pnam�y 0 thegroup theGroup
�x .BDSKAdd null���     ****
�w 
from
�v .BDSKRemvnull���     ****
�u 
Libr
�t 
auth
�s 
aunm
�r 
File�q 0 thefiles theFiles
�p 
URL �o 0 theurls theURLs
�n 
titl
�m 
bfld�l 0 thefield theField
�k 
fldv�j  0 nonemptyfields nonEmptyFields
�i 
gcky�h 0 	theauthor 	theAuthor�g 0 hispubs hisPubs
�f .BDSKshownull��� ��� obj 
�e 
filt
�d 
disp
�c .BDSKsrch****  @     obj 
�b 
pfol�a "0 thepapersfolder thePapersFolder
�` 
psxf
�_ .coredoexbool        obj 
�^ 
alis
�] .aevtodocnull  �    alis
�\ 
atyp
�[ 
afnm���{*j O*��l O*�k/EE�O��*���*�-5� E�O��*�-6l 
E�O�j O*�-j O�E�O*�����l�*�-5a  E�O��,EE�O*�����l�*�-6a  E�O*�-a [a ,\Za @1E` O_ *a ,FO*a ,E` O_ a k/EE` O*a a a _ � O*�a �a a l� E`  O_ �_  l !O_ a "_  l #O*a $k/�-EO_  �*a %-a &,EO*a '-EE` (O*a )-E` *Oa +*a ,,FO*a -a ./EE` /O*a -a 0/a 1,EOa 2*a -a 3/a 1,FO*a --a ,EE` 4O*a ,EO*a 5,E*a ,FO*a %k/EE` 6O_ 6a ,EOa 7�*a )-6l !OPUO*a %a 8/EE` 6O_ 6�-EE` 9O_ j :O_ 6j :O*a ;,a <  a =*a ;,FY a >*a ;,FO*a ?,EO*a a @l AOPUO*a a Bl AO*�k/a a Cl AO*�- a D*a ;,FUO*a E,E` FOa G %*a H_ F/j I *a H_ F/a J&j KY hUO*a L,EO*a M,EOPUascr  ��ޭ