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
 l     ��������  ��  ��        l   ^ ����  O    ^    k   ]       l   ��  ��      start BibDesk     �      s t a r t   B i b D e s k      I   	������
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
docu 0 m    ����  . o      ���� 0 thedoc theDoc ,  1 2 1 l   ��������  ��  ��   2  3 4 3 l  � 5 6 7 5 O   � 8 9 8 k   � : :  ; < ; l   ��������  ��  ��   <  = > = l   �� ? @��   ? + % GENERATING AND DELETING PUBLICATIONS    @ � A A J   G E N E R A T I N G   A N D   D E L E T I N G   P U B L I C A T I O N S >  B C B l   �� D E��   D ) # let's make a new empty publication    E � F F F   l e t ' s   m a k e   a   n e w   e m p t y   p u b l i c a t i o n C  G H G r    , I J I I   *���� K
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
bibi��   n  p q p l  H H�� r s��   r %  make some BibTeX record to use    s � t t >   m a k e   s o m e   B i b T e X   r e c o r d   t o   u s e q  u v u r   H K w x w m   H I y y � z z � @ a r t i c l e { M c C r a c k e n : 2 0 0 5 ,   A u t h o r   =   { M .   M c C r a c k e n   a n d   A .   M a x w e l l } ,   T i t l e   =   { W o r k i n g   w i t h   B i b D e s k . } , Y e a r = { 2 0 0 5 } } x o      ���� "0 thebibtexrecord theBibTeXRecord v  { | { l  L L�� } ~��   } 9 3 now make a new publication with this BibTeX string    ~ �   f   n o w   m a k e   a   n e w   p u b l i c a t i o n   w i t h   t h i s   B i b T e X   s t r i n g |  � � � l  L L�� � ���   � 5 / note: the BibTeX string property cannot be set    � � � � ^   n o t e :   t h e   B i b T e X   s t r i n g   p r o p e r t y   c a n n o t   b e   s e t �  � � � r   L U � � � I  L S���� �
�� .BDSKImptnull���     docu��   � �� ���
�� 
from � o   N O���� "0 thebibtexrecord theBibTeXRecord��   � o      ���� 0 newpub newPub �  � � � l  V V�� � ���   � + % we can get the BibTeX record as well    � � � � J   w e   c a n   g e t   t h e   B i b T e X   r e c o r d   a s   w e l l �  � � � r   V ^ � � � e   V \ � � n   V \ � � � 1   W [��
�� 
BTeX � o   V W���� 0 newpub newPub � o      ���� "0 thebibtexrecord theBibTeXRecord �  � � � l  _ _��������  ��  ��   �  � � � l  _ _�� � ���   � !  MANIPULATING THE SELECTION    � � � � 6   M A N I P U L A T I N G   T H E   S E L E C T I O N �  � � � l  _ _�� � ���   � L F Play with the selection and put styled bibliography on the clipboard.    � � � � �   P l a y   w i t h   t h e   s e l e c t i o n   a n d   p u t   s t y l e d   b i b l i o g r a p h y   o n   t h e   c l i p b o a r d . �  � � � r   _ u � � � l  _ q ����� � 6  _ q � � � 2  _ b��
�� 
bibi � E   e p � � � 1   f j��
�� 
ckey � m   k o � � � � �  M c C r a c k e n��  ��   � o      ���� 0 somepubs somePubs �  � � � r   v  � � � o   v y���� 0 somepubs somePubs � l      ����� � 1   y ~��
�� 
sele��  ��   �  � � � l  � ��� � ���   �   get the selection    � � � � $   g e t   t h e   s e l e c t i o n �  � � � r   � � � � � l  � � ����� � 1   � ���
�� 
sele��  ��   � o      ���� 0 theselection theSelection �  � � � l  � ��� � ���   �   and get its first item    � � � � .   a n d   g e t   i t s   f i r s t   i t e m �  � � � r   � � � � � e   � � � � n   � � � � � 4   � ��� �
�� 
cobj � m   � �����  � o   � ����� 0 theselection theSelection � o      ���� 0 thepub thePub �  � � � l  � ���������  ��  ��   �  � � � l  � ��� � ���   � 1 + get a text representation using a template    � � � � V   g e t   a   t e x t   r e p r e s e n t a t i o n   u s i n g   a   t e m p l a t e �  � � � e   � � � � I  � ����� �
�� .BDSKttxtTEXT        docu��   � �� � �
�� 
usng � m   � � � � � � � * D e f a u l t   H T M L   t e m p l a t e � �� ���
�� 
for  � o   � ����� 0 theselection theSelection��   �  � � � l  � ���������  ��  ��   �  � � � l  � ��� � ���   �   GROUPS    � � � �    G R O U P S �  � � � l  � ��� � ���   �   make a new static group    � � � � 0   m a k e   a   n e w   s t a t i c   g r o u p �  � � � r   � � � � � I  � ����� �
�� .corecrel****      � null��   � �� � �
�� 
kocl � m   � ���
�� 
StGp � �� ���
�� 
prdt � K   � � � � �� ���
�� 
pnam � m   � � � � � � �  S t a t i c   G r o u p��  ��   � o      ���� 0 thegroup theGroup �  � � � l  � ��� � ���   � E ? add our item to the group, you cannot add to an external group    � � � � ~   a d d   o u r   i t e m   t o   t h e   g r o u p ,   y o u   c a n n o t   a d d   t o   a n   e x t e r n a l   g r o u p �  � � � I  � ��� � �
�� .BDSKAdd null���     **** � o   � ����� 0 thepub thePub � �� ���
�� 
insh � o   � ����� 0 thegroup theGroup��   �  � � � l  � �� � ��   �   and remove it again    � �   (   a n d   r e m o v e   i t   a g a i n �  I  � ��~
�~ .BDSKRemvnull���     **** o   � ��}�} 0 thepub thePub �|�{
�| 
from o   � ��z�z 0 thegroup theGroup�{    l  � ��y	�y   R L groups are always to-many relationships, even if there is only a single one   	 �

 �   g r o u p s   a r e   a l w a y s   t o - m a n y   r e l a t i o n s h i p s ,   e v e n   i f   t h e r e   i s   o n l y   a   s i n g l e   o n e  l  � ��x�w n   � � 2  � ��v
�v 
bibi 4   � ��u
�u 
Libr m   � ��t�t �x  �w    l  � ��s�r�q�s  �r  �q    l  � ��p�p   , & ACCESSING PROPERTIES OF A PUBLICATION    � L   A C C E S S I N G   P R O P E R T I E S   O F   A   P U B L I C A T I O N  l  �� O   �� k   ��  !  l  � ��o�n�m�o  �n  �m  ! "#" l  � ��l$%�l  $ 1 + all properties give quite a lengthy output   % �&& V   a l l   p r o p e r t i e s   g i v e   q u i t e   a   l e n g t h y   o u t p u t# '(' l  � ��k)*�k  )   get properties   * �++    g e t   p r o p e r t i e s( ,-, l  � ��j�i�h�j  �i  �h  - ./. l  � ��g01�g  0 I C plurals as well as accessing a whole array of things  work as well   1 �22 �   p l u r a l s   a s   w e l l   a s   a c c e s s i n g   a   w h o l e   a r r a y   o f   t h i n g s     w o r k   a s   w e l l/ 343 n   � �565 1   � ��f
�f 
aunm6 2  � ��e
�e 
auth4 787 l  � ��d�c�b�d  �c  �b  8 9:9 l  � ��a;<�a  ; ) # as does access to the linked files   < �== F   a s   d o e s   a c c e s s   t o   t h e   l i n k e d   f i l e s: >?> r   � @A@ e   � �BB 2  � ��`
�` 
FileA o      �_�_ 0 thefiles theFiles? CDC l �^EF�^  E � � Note this is an array of file objects which can be 'missing value' when the file was not found. You can get the POSIX path of a linked file or the URL as a string. In the latter case you need to get the URL of a reference.   F �GG�   N o t e   t h i s   i s   a n   a r r a y   o f   f i l e   o b j e c t s   w h i c h   c a n   b e   ' m i s s i n g   v a l u e '   w h e n   t h e   f i l e   w a s   n o t   f o u n d .   Y o u   c a n   g e t   t h e   P O S I X   p a t h   o f   a   l i n k e d   f i l e   o r   t h e   U R L   a s   a   s t r i n g .   I n   t h e   l a t t e r   c a s e   y o u   n e e d   t o   g e t   t h e   U R L   o f   a   r e f e r e n c e .D HIH l �]JK�]  J  POSIX path of theFiles   K �LL , P O S I X   p a t h   o f   t h e F i l e sI MNM l �\OP�\  O  URL of linked file 1   P �QQ ( U R L   o f   l i n k e d   f i l e   1N RSR l �[�Z�Y�[  �Z  �Y  S TUT l �XVW�X  V   and the linked URLs   W �XX (   a n d   t h e   l i n k e d   U R L sU YZY r  
[\[ 2 �W
�W 
URL \ o      �V�V 0 theurls theURLsZ ]^] l �U�T�S�U  �T  �S  ^ _`_ l �Rab�R  a #  we can easily set properties   b �cc :   w e   c a n   e a s i l y   s e t   p r o p e r t i e s` ded r  fgf m  hh �ii * W o r k i n g   w i t h   B i b D e s k .g 1  �Q
�Q 
title jkj l �P�O�N�P  �O  �N  k lml l �Mno�M  n 0 * we can access all fields and their values   o �pp T   w e   c a n   a c c e s s   a l l   f i e l d s   a n d   t h e i r   v a l u e sm qrq r  "sts e  uu 4  �Lv
�L 
bfldv m  ww �xx  A u t h o rt o      �K�K 0 thefield theFieldr yzy e  #0{{ n  #0|}| 1  +/�J
�J 
fldv} 4  #+�I~
�I 
bfld~ m  '* ��� 
 T i t l ez ��� r  1A��� m  14�� ���  S o u r c e F o r g e� n      ��� 1  <@�H
�H 
fldv� 4  4<�G�
�G 
bfld� m  8;�� ���  J o u r n a l� ��� l BB�F�E�D�F  �E  �D  � ��� l BB�C���C  � J D we can also get a list of all non-empty fields and their properties   � ��� �   w e   c a n   a l s o   g e t   a   l i s t   o f   a l l   n o n - e m p t y   f i e l d s   a n d   t h e i r   p r o p e r t i e s� ��� r  BP��� e  BL�� n  BL��� 1  GK�B
�B 
pnam� 2 BG�A
�A 
bfld� o      �@�@  0 nonemptyfields nonEmptyFields� ��� l QQ�?�>�=�?  �>  �=  � ��� l QQ�<���<  �  
 CITE KEYS   � ���    C I T E   K E Y S� ��� l QQ�;���;  � 9 3 you can access the cite key and generate a new one   � ��� f   y o u   c a n   a c c e s s   t h e   c i t e   k e y   a n d   g e n e r a t e   a   n e w   o n e� ��� e  QW�� 1  QW�:
�: 
ckey� ��� r  Xd��� e  X^�� 1  X^�9
�9 
gcky� 1  ^c�8
�8 
ckey� ��� l ee�7�6�5�7  �6  �5  � ��� l ee�4���4  �   AUTHORS   � ���    A U T H O R S� ��� l ee�3���3  � 7 1 we can also query all authors in the publciation   � ��� b   w e   c a n   a l s o   q u e r y   a l l   a u t h o r s   i n   t h e   p u b l c i a t i o n� ��� r  ep��� e  el�� 4 el�2�
�2 
auth� m  ij�1�1 � o      �0�0 0 	theauthor 	theAuthor� ��� l qq�/���/  � E ? this is the normalized name of the form 'von Last, First, Jr.'   � ��� ~   t h i s   i s   t h e   n o r m a l i z e d   n a m e   o f   t h e   f o r m   ' v o n   L a s t ,   F i r s t ,   J r . '� ��� n  qy��� 1  tx�.
�. 
pnam� o  qt�-�- 0 	theauthor 	theAuthor� ��� l zz�,�+�*�,  �+  �*  � ��� l zz�)���)  �   LINKED FILES and URLs   � ��� ,   L I N K E D   F I L E S   a n d   U R L s� ��� l zz�(���(  �   add a new linked URL   � ��� *   a d d   a   n e w   l i n k e d   U R L� ��� I z��'��
�' .BDSKAdd null���     ****� m  z}�� ��� * h t t p : / / m y h o s t / f o o / b a r� �&��%
�& 
insh� n  ~����  ;  ��� 2 ~��$
�$ 
URL �%  � ��� l ���#���#  � F @add (POSIX file "/path/to/my/file") to beginning of linked files   � ��� � a d d   ( P O S I X   f i l e   " / p a t h / t o / m y / f i l e " )   t o   b e g i n n i n g   o f   l i n k e d   f i l e s� ��"� l ���!� ��!  �   �  �"   o   � ��� 0 thepub thePub   thePub    ���    t h e P u b ��� l ������  �  �  � ��� l ������  � !  work again on the document   � ��� 6   w o r k   a g a i n   o n   t h e   d o c u m e n t� ��� l ������  �  �  � ��� l ������  �   AUTHORS   � ���    A U T H O R S� ��� l ������  � � � we can also query all authors present in the current document. To find an author by name, it is preferrable to use the (normalized) name. You can also use the 'full name' property though.   � ���x   w e   c a n   a l s o   q u e r y   a l l   a u t h o r s   p r e s e n t   i n   t h e   c u r r e n t   d o c u m e n t .   T o   f i n d   a n   a u t h o r   b y   n a m e ,   i t   i s   p r e f e r r a b l e   t o   u s e   t h e   ( n o r m a l i z e d )   n a m e .   Y o u   c a n   a l s o   u s e   t h e   ' f u l l   n a m e '   p r o p e r t y   t h o u g h .� ��� r  ����� e  ���� 4  ����
� 
auth� m  ���� ���  M c C r a c k e n ,   M .� o      �� 0 	theauthor 	theAuthor�    l ����   $  and find all his publications    � <   a n d   f i n d   a l l   h i s   p u b l i c a t i o n s  r  �� e  ��		 n  ��

 2 ���
� 
bibi o  ���� 0 	theauthor 	theAuthor o      �� 0 hispubs hisPubs  l ������  �  �    l ����     OPENING WINDOWS    �     O P E N I N G   W I N D O W S  l ���
�
   _ Y we can open the editor window for a publication and the information window for an author    � �   w e   c a n   o p e n   t h e   e d i t o r   w i n d o w   f o r   a   p u b l i c a t i o n   a n d   t h e   i n f o r m a t i o n   w i n d o w   f o r   a n   a u t h o r  I ���	�
�	 .BDSKshownull��� ��� obj  o  ���� 0 thepub thePub�    I ����
� .BDSKshownull��� ��� obj  o  ���� 0 	theauthor 	theAuthor�    l ������  �  �    !  l ��� "#�   "   FILTERING AND SEARCHING   # �$$ 0   F I L T E R I N G   A N D   S E A R C H I N G! %&% l ����'(��  ' y s we can get and set the filter field of each document and get the list of publications that is currently displayed.   ( �)) �   w e   c a n   g e t   a n d   s e t   t h e   f i l t e r   f i e l d   o f   e a c h   d o c u m e n t   a n d   g e t   t h e   l i s t   o f   p u b l i c a t i o n s   t h a t   i s   c u r r e n t l y   d i s p l a y e d .& *+* l ����,-��  ,�� in addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.   - �..2   i n   a d d i t i o n   t h e r e   i s   t h e   s e a r c h   c o m m a n d   w h i c h   r e t u r n s   t h e   r e s u l t s   o f   a   s e a r c h .   T h a t   s e a r c h   m a t c h e s   o n l y   t h e   c i t e   k e y ,   t h e   a u t h o r s '   s u r n a m e s   a n d   t h e   p u b l i c a t i o n ' s   t i t l e .   W a r n i n g :   i t s   r e s u l t s   m a y   b e   d i f f e r e n t   f r o m   w h a t ' s   s e e n   w h e n   u s i n g   t h e   f i l t e r   f i e l d   f o r   t h e   s a m e   t e r m .   I t   i s   m a i n l y   i n t e n d e d   f o r   a u t o c o m p l e t i o n   u s e   a n d   u s i n g   ' w h o s e '   s t a t e m e n t s   t o   s e a r c h   f o r   p u b l i c a t i o n s   s h o u l d   b e   m o r e   p o w e r f u l ,   b u t   s l o w e r .+ /0/ Z  ��12��31 = ��454 1  ����
�� 
filt5 m  ��66 �77  2 r  ��898 m  ��:: �;;  M c C r a c k e n9 1  ����
�� 
filt��  3 r  ��<=< m  ��>> �??  = 1  ����
�� 
filt0 @A@ e  ��BB 1  ����
�� 
dispA CDC e  ��EE I ������F
�� .BDSKsrch****  @     obj ��  F ��G��
�� 
for G m  ��HH �II  M c C r a c k e n��  D JKJ l ����LM��  L r l when writing an AppleScript for completion support in other applications use the 'for completion' parameter   M �NN �   w h e n   w r i t i n g   a n   A p p l e S c r i p t   f o r   c o m p l e t i o n   s u p p o r t   i n   o t h e r   a p p l i c a t i o n s   u s e   t h e   ' f o r   c o m p l e t i o n '   p a r a m e t e rK OPO l ����QR��  Q 3 -get search for "McCracken" for completion yes   R �SS Z g e t   s e a r c h   f o r   " M c C r a c k e n "   f o r   c o m p l e t i o n   y e sP T��T l ����������  ��  ��  ��   9 o    ���� 0 thedoc theDoc 6   theDoc    7 �UU    t h e D o c 4 VWV l ����������  ��  ��  W XYX l ����Z[��  Z $  work again on the application   [ �\\ <   w o r k   a g a i n   o n   t h e   a p p l i c a t i o nY ]^] l ����������  ��  ��  ^ _`_ l ����ab��  a � � the search command works also at application level. It will either search every document in that case, or the one it is addressed to.   b �cc   t h e   s e a r c h   c o m m a n d   w o r k s   a l s o   a t   a p p l i c a t i o n   l e v e l .   I t   w i l l   e i t h e r   s e a r c h   e v e r y   d o c u m e n t   i n   t h a t   c a s e ,   o r   t h e   o n e   i t   i s   a d d r e s s e d   t o .` ded I ������f
�� .BDSKsrch****  @     obj ��  f ��g��
�� 
for g m  ��hh �ii  M c C r a c k e n��  e jkj I ���lm
�� .BDSKsrch****  @     obj l 4 ����n
�� 
docun m  ������ m ��o��
�� 
for o m   pp �qq  M c C r a c k e n��  k rsr l ��tu��  t  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.   u �vv �   A p p l e S c r i p t   l e t s   u s   e a s i l y   s e t   t h e   f i l t e r   f i e l d   i n   a l l   o p e n   d o c u m e n t s .   T h i s   i s   u s e d   i n   t h e   L a u n c h B a r   i n t e g r a t i o n   s c r i p t .s wxw O yzy r  {|{ m  }} �~~  M c C r a c k e n| 1  ��
�� 
filtz 2  ��
�� 
docux � l ��������  ��  ��  � ��� l ������  �   GLOBAL PROPERTIES   � ��� $   G L O B A L   P R O P E R T I E S� ��� l ������  � 4 . you can get the folder where papers are filed   � ��� \   y o u   c a n   g e t   t h e   f o l d e r   w h e r e   p a p e r s   a r e   f i l e d� ��� r  "��� l ������ 1  ��
�� 
pfol��  ��  � o      ���� "0 thepapersfolder thePapersFolder� ��� l ##������  � s m it is a UNIX (i.e. POSIX) style path, so if we want to use it we should translate it into a Mac style path.    � ��� �   i t   i s   a   U N I X   ( i . e .   P O S I X )   s t y l e   p a t h ,   s o   i f   w e   w a n t   t o   u s e   i t   w e   s h o u l d   t r a n s l a t e   i t   i n t o   a   M a c   s t y l e   p a t h .  � ��� O  #M��� Z  )L������� I )5�����
�� .coredoexbool        obj � 4  )1���
�� 
psxf� o  -0���� "0 thepapersfolder thePapersFolder��  � I 8H�����
�� .aevtodocnull  �    alis� c  8D��� l 8@������ 4  8@���
�� 
psxf� o  <?���� "0 thepapersfolder thePapersFolder��  ��  � m  @C��
�� 
alis��  ��  ��  � m  #&���                                                                                  MACS   alis    r  Macintosh HD               ũ��H+     u
Finder.app                                                       v��R�u        ����  	                CoreServices    ũ��      �Rve       u   1   0  3Macintosh HD:System:Library:CoreServices:Finder.app    
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��  � ��� l NN��������  ��  ��  � ��� l NN������  � %  get all known types and fields   � ��� >   g e t   a l l   k n o w n   t y p e s   a n d   f i e l d s� ��� e  NT�� 1  NT��
�� 
atyp� ��� e  U[�� 1  U[��
�� 
afnm� ���� l \\��������  ��  ��  ��    m     ���                                                                                  BDSK   alis    �  Macintosh HD               ũ��H+   CsBibDesk.app                                                     �}Ǝd        ����  	                Debug     ũ��      Ǝ D     Cs � XR 
��  |S  EMacintosh HD:Users:hofman:Development:BuildProducts:Debug:BibDesk.app     B i b D e s k . a p p    M a c i n t o s h   H D  8Users/hofman/Development/BuildProducts/Debug/BibDesk.app  /    ��  ��  ��    ��� l     ��������  ��  ��  � ���� l     ��������  ��  ��  ��       ������  � ��
�� .aevtoappnull  �   � ****� �����������
�� .aevtoappnull  �   � ****� k    ^��  ����  ��  ��  �  � N����������������������� y����������� ������������� ����������� ���������������������h����w��������������~�}�|6:>�{H�zhp}�y�x��w�v�u�t�s�r
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
from
�� .BDSKImptnull���     docu
�� 
BTeX�  
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
StGp
�� 
prdt
�� 
pnam�� 0 thegroup theGroup
�� .BDSKAdd null���     ****
�� .BDSKRemvnull���     ****
�� 
Libr
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
fldv��  0 nonemptyfields nonEmptyFields
�� 
gcky� 0 	theauthor 	theAuthor�~ 0 hispubs hisPubs
�} .BDSKshownull��� ��� obj 
�| 
filt
�{ 
disp
�z .BDSKsrch****  @     obj 
�y 
pfol�x "0 thepapersfolder thePapersFolder
�w 
psxf
�v .coredoexbool        obj 
�u 
alis
�t .aevtodocnull  �    alis
�s 
atyp
�r 
afnm��_�[*j O*��l O*�k/EE�O��*���*�-5� E�O��*�-6l 
E�O�j O*�-j O�E�O*��l E�O�a ,EE�O*�-a [a ,\Za @1E` O_ *a ,FO*a ,E` O_ a k/EE` O*a a a _ � O*�a a a a  l� E` !O_ �_ !l "O_ �_ !l #O*a $k/�-EO_  �*a %-a &,EO*a '-EE` (O*a )-E` *Oa +*a ,,FO*a -a ./EE` /O*a -a 0/a 1,EOa 2*a -a 3/a 1,FO*a --a ,EE` 4O*a ,EO*a 5,E*a ,FO*a %k/EE` 6O_ 6a ,EOa 7�*a )-6l "OPUO*a %a 8/EE` 6O_ 6�-EE` 9O_ j :O_ 6j :O*a ;,a <  a =*a ;,FY a >*a ;,FO*a ?,EO*a a @l AOPUO*a a Bl AO*�k/a a Cl AO*�- a D*a ;,FUO*a E,E` FOa G %*a H_ F/j I *a H_ F/a J&j KY hUO*a L,EO*a M,EOPUascr  ��ޭ