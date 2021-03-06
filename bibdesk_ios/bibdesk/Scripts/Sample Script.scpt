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
 l     ��������  ��  ��        l   b ����  O    b    k   a       l   ��  ��      start BibDesk     �      s t a r t   B i b D e s k      I   	������
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
bibi��   Z o      ���� 0 newpub newPub X  ` a ` l  : :�� b c��   b [ U get rid of the new publication, but 'duplicate' is buggy and doesn't return anything    c � d d �   g e t   r i d   o f   t h e   n e w   p u b l i c a t i o n ,   b u t   ' d u p l i c a t e '   i s   b u g g y   a n d   d o e s n ' t   r e t u r n   a n y t h i n g a  e f e l  : :�� g h��   g  delete newPub    h � i i  d e l e t e   n e w P u b f  j k j l  : :�� l m��   l "  get rid of all publications    m � n n 8   g e t   r i d   o f   a l l   p u b l i c a t i o n s k  o p o I  : A�� q��
�� .coredelonull���     obj  q 2  : =��
�� 
bibi��   p  r s r l  B B�� t u��   t %  make some BibTeX record to use    u � v v >   m a k e   s o m e   B i b T e X   r e c o r d   t o   u s e s  w x w r   B E y z y m   B C { { � | | � @ a r t i c l e { M c C r a c k e n : 2 0 0 5 ,   A u t h o r   =   { M .   M c C r a c k e n   a n d   A .   M a x w e l l } ,   T i t l e   =   { W o r k i n g   w i t h   B i b D e s k . } , Y e a r = { 2 0 0 5 } } z o      ���� "0 thebibtexrecord theBibTeXRecord x  } ~ } l  F F��  ���    9 3 now make a new publication with this BibTeX string    � � � � f   n o w   m a k e   a   n e w   p u b l i c a t i o n   w i t h   t h i s   B i b T e X   s t r i n g ~  � � � l  F F�� � ���   � 5 / note: the BibTeX string property cannot be set    � � � � ^   n o t e :   t h e   B i b T e X   s t r i n g   p r o p e r t y   c a n n o t   b e   s e t �  � � � r   F Q � � � I  F M���� �
�� .BDSKImptnull���     docu��   � �� ���
�� 
from � o   H I���� "0 thebibtexrecord theBibTeXRecord��   � o      ���� 0 newpubs newPubs �  � � � l  R R�� � ���   � + % we can get the BibTeX record as well    � � � � J   w e   c a n   g e t   t h e   B i b T e X   r e c o r d   a s   w e l l �  � � � r   R b � � � e   R ` � � n   R ` � � � 1   [ _��
�� 
BTeX � l  R [ ����� � e   R [ � � n   R [ � � � 4   U Z�� �
�� 
cobj � m   X Y����  � o   R U���� 0 newpubs newPubs��  ��   � o      ���� "0 thebibtexrecord theBibTeXRecord �  � � � l  c c��������  ��  ��   �  � � � l  c c�� � ���   � !  MANIPULATING THE SELECTION    � � � � 6   M A N I P U L A T I N G   T H E   S E L E C T I O N �  � � � l  c c�� � ���   � L F Play with the selection and put styled bibliography on the clipboard.    � � � � �   P l a y   w i t h   t h e   s e l e c t i o n   a n d   p u t   s t y l e d   b i b l i o g r a p h y   o n   t h e   c l i p b o a r d . �  � � � r   c y � � � l  c u ����� � 6  c u � � � 2  c f��
�� 
bibi � E   i t � � � 1   j n��
�� 
ckey � m   o s � � � � �  M c C r a c k e n��  ��   � o      ���� 0 somepubs somePubs �  � � � r   z � � � � o   z }���� 0 somepubs somePubs � l      ����� � 1   } ���
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
pnam � m   � � � � � � �  S t a t i c   G r o u p��  ��   � o      ���� 0 thegroup theGroup �  � � � l  � ��� � ���   � E ? add our item to the group, you cannot add to an external group    � � � � ~   a d d   o u r   i t e m   t o   t h e   g r o u p ,   y o u   c a n n o t   a d d   t o   a n   e x t e r n a l   g r o u p �  � � � I  � ��� 
�� .BDSKAdd null���     ****  o   � ����� 0 thepub thePub ���
�� 
insh o   � ��~�~ 0 thegroup theGroup�   �  l  � ��}�}     and remove it again    � (   a n d   r e m o v e   i t   a g a i n 	 I  � ��|

�| .BDSKRemvnull���     ****
 o   � ��{�{ 0 thepub thePub �z�y
�z 
from o   � ��x�x 0 thegroup theGroup�y  	  l  � ��w�w   R L groups are always to-many relationships, even if there is only a single one    � �   g r o u p s   a r e   a l w a y s   t o - m a n y   r e l a t i o n s h i p s ,   e v e n   i f   t h e r e   i s   o n l y   a   s i n g l e   o n e  l  � ��v�u n   � � 2  � ��t
�t 
bibi 4   � ��s
�s 
Libr m   � ��r�r �v  �u    l  � ��q�p�o�q  �p  �o    l  � ��n�n   , & ACCESSING PROPERTIES OF A PUBLICATION    � L   A C C E S S I N G   P R O P E R T I E S   O F   A   P U B L I C A T I O N   l  ��!"#! O   ��$%$ k   ��&& '(' l  � ��m�l�k�m  �l  �k  ( )*) l  � ��j+,�j  + 1 + all properties give quite a lengthy output   , �-- V   a l l   p r o p e r t i e s   g i v e   q u i t e   a   l e n g t h y   o u t p u t* ./. l  � ��i01�i  0   get properties   1 �22    g e t   p r o p e r t i e s/ 343 l  � ��h�g�f�h  �g  �f  4 565 l  � ��e78�e  7 I C plurals as well as accessing a whole array of things  work as well   8 �99 �   p l u r a l s   a s   w e l l   a s   a c c e s s i n g   a   w h o l e   a r r a y   o f   t h i n g s     w o r k   a s   w e l l6 :;: n   � �<=< 1   � ��d
�d 
aunm= 2  � ��c
�c 
auth; >?> l  � ��b�a�`�b  �a  �`  ? @A@ l  � ��_BC�_  B ) # as does access to the linked files   C �DD F   a s   d o e s   a c c e s s   t o   t h e   l i n k e d   f i l e sA EFE r   �GHG e   � II 2  � �^
�^ 
FileH o      �]�] 0 thefiles theFilesF JKJ l �\LM�\  L � � Note this is an array of file objects which can be 'missing value' when the file was not found. You can get the POSIX path of a linked file or the URL as a string. In the latter case you need to get the URL of a reference.   M �NN�   N o t e   t h i s   i s   a n   a r r a y   o f   f i l e   o b j e c t s   w h i c h   c a n   b e   ' m i s s i n g   v a l u e '   w h e n   t h e   f i l e   w a s   n o t   f o u n d .   Y o u   c a n   g e t   t h e   P O S I X   p a t h   o f   a   l i n k e d   f i l e   o r   t h e   U R L   a s   a   s t r i n g .   I n   t h e   l a t t e r   c a s e   y o u   n e e d   t o   g e t   t h e   U R L   o f   a   r e f e r e n c e .K OPO l �[QR�[  Q  POSIX path of theFiles   R �SS , P O S I X   p a t h   o f   t h e F i l e sP TUT l �ZVW�Z  V  URL of linked file 1   W �XX ( U R L   o f   l i n k e d   f i l e   1U YZY l �Y�X�W�Y  �X  �W  Z [\[ l �V]^�V  ]   and the linked URLs   ^ �__ (   a n d   t h e   l i n k e d   U R L s\ `a` r  bcb 2 
�U
�U 
URL c o      �T�T 0 theurls theURLsa ded l �S�R�Q�S  �R  �Q  e fgf l �Phi�P  h #  we can easily set properties   i �jj :   w e   c a n   e a s i l y   s e t   p r o p e r t i e sg klk r  mnm m  oo �pp * W o r k i n g   w i t h   B i b D e s k .n 1  �O
�O 
titll qrq l �N�M�L�N  �M  �L  r sts l �Kuv�K  u 0 * we can access all fields and their values   v �ww T   w e   c a n   a c c e s s   a l l   f i e l d s   a n d   t h e i r   v a l u e st xyx r  &z{z e  "|| 4  "�J}
�J 
bfld} m   ~~ �  A u t h o r{ o      �I�I 0 thefield theFieldy ��� e  '4�� n  '4��� 1  /3�H
�H 
fldv� 4  '/�G�
�G 
bfld� m  +.�� ��� 
 T i t l e� ��� r  5E��� m  58�� ���  S o u r c e F o r g e� n      ��� 1  @D�F
�F 
fldv� 4  8@�E�
�E 
bfld� m  <?�� ���  J o u r n a l� ��� l FF�D�C�B�D  �C  �B  � ��� l FF�A���A  � J D we can also get a list of all non-empty fields and their properties   � ��� �   w e   c a n   a l s o   g e t   a   l i s t   o f   a l l   n o n - e m p t y   f i e l d s   a n d   t h e i r   p r o p e r t i e s� ��� r  FT��� e  FP�� n  FP��� 1  KO�@
�@ 
pnam� 2 FK�?
�? 
bfld� o      �>�>  0 nonemptyfields nonEmptyFields� ��� l UU�=�<�;�=  �<  �;  � ��� l UU�:���:  �  
 CITE KEYS   � ���    C I T E   K E Y S� ��� l UU�9���9  � 9 3 you can access the cite key and generate a new one   � ��� f   y o u   c a n   a c c e s s   t h e   c i t e   k e y   a n d   g e n e r a t e   a   n e w   o n e� ��� e  U[�� 1  U[�8
�8 
ckey� ��� r  \h��� e  \b�� 1  \b�7
�7 
gcky� 1  bg�6
�6 
ckey� ��� l ii�5�4�3�5  �4  �3  � ��� l ii�2���2  �   AUTHORS   � ���    A U T H O R S� ��� l ii�1���1  � 7 1 we can also query all authors in the publciation   � ��� b   w e   c a n   a l s o   q u e r y   a l l   a u t h o r s   i n   t h e   p u b l c i a t i o n� ��� r  it��� e  ip�� 4 ip�0�
�0 
auth� m  mn�/�/ � o      �.�. 0 	theauthor 	theAuthor� ��� l uu�-���-  � E ? this is the normalized name of the form 'von Last, First, Jr.'   � ��� ~   t h i s   i s   t h e   n o r m a l i z e d   n a m e   o f   t h e   f o r m   ' v o n   L a s t ,   F i r s t ,   J r . '� ��� n  u}��� 1  x|�,
�, 
pnam� o  ux�+�+ 0 	theauthor 	theAuthor� ��� l ~~�*�)�(�*  �)  �(  � ��� l ~~�'���'  �   LINKED FILES and URLs   � ��� ,   L I N K E D   F I L E S   a n d   U R L s� ��� l ~~�&���&  �   add a new linked URL   � ��� *   a d d   a   n e w   l i n k e d   U R L� ��� I ~��%��
�% .BDSKAdd null���     ****� m  ~��� ��� * h t t p : / / m y h o s t / f o o / b a r� �$��#
�$ 
insh� n  �����  ;  ��� 2 ���"
�" 
URL �#  � ��� l ���!���!  � F @add (POSIX file "/path/to/my/file") to beginning of linked files   � ��� � a d d   ( P O S I X   f i l e   " / p a t h / t o / m y / f i l e " )   t o   b e g i n n i n g   o f   l i n k e d   f i l e s� �� � l ������  �  �  �   % o   � ��� 0 thepub thePub"   thePub   # ���    t h e P u b  ��� l ������  �  �  � ��� l ������  � !  work again on the document   � ��� 6   w o r k   a g a i n   o n   t h e   d o c u m e n t� ��� l ������  �  �  � ��� l ������  �   AUTHORS   � ���    A U T H O R S� ��� l ������  � � � we can also query all authors present in the current document. To find an author by name, it is preferrable to use the (normalized) name. You can also use the 'full name' property though.   � ���x   w e   c a n   a l s o   q u e r y   a l l   a u t h o r s   p r e s e n t   i n   t h e   c u r r e n t   d o c u m e n t .   T o   f i n d   a n   a u t h o r   b y   n a m e ,   i t   i s   p r e f e r r a b l e   t o   u s e   t h e   ( n o r m a l i z e d )   n a m e .   Y o u   c a n   a l s o   u s e   t h e   ' f u l l   n a m e '   p r o p e r t y   t h o u g h .� � � r  �� e  �� 4  ���
� 
auth m  �� �  M c C r a c k e n ,   M . o      �� 0 	theauthor 	theAuthor   l ���	
�  	 $  and find all his publications   
 � <   a n d   f i n d   a l l   h i s   p u b l i c a t i o n s  r  �� e  �� n  �� 2 ���
� 
bibi o  ���� 0 	theauthor 	theAuthor o      �� 0 hispubs hisPubs  l �����
�  �  �
    l ���	�	     OPENING WINDOWS    �     O P E N I N G   W I N D O W S  l ����   _ Y we can open the editor window for a publication and the information window for an author    � �   w e   c a n   o p e n   t h e   e d i t o r   w i n d o w   f o r   a   p u b l i c a t i o n   a n d   t h e   i n f o r m a t i o n   w i n d o w   f o r   a n   a u t h o r   I ���!�
� .BDSKshownull��� ��� obj ! o  ���� 0 thepub thePub�    "#" I ���$�
� .BDSKshownull��� ��� obj $ o  ���� 0 	theauthor 	theAuthor�  # %&% l ���� ���  �   ��  & '(' l ����)*��  )   FILTERING AND SEARCHING   * �++ 0   F I L T E R I N G   A N D   S E A R C H I N G( ,-, l ����./��  . y s we can get and set the filter field of each document and get the list of publications that is currently displayed.   / �00 �   w e   c a n   g e t   a n d   s e t   t h e   f i l t e r   f i e l d   o f   e a c h   d o c u m e n t   a n d   g e t   t h e   l i s t   o f   p u b l i c a t i o n s   t h a t   i s   c u r r e n t l y   d i s p l a y e d .- 121 l ����34��  3�� in addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.   4 �552   i n   a d d i t i o n   t h e r e   i s   t h e   s e a r c h   c o m m a n d   w h i c h   r e t u r n s   t h e   r e s u l t s   o f   a   s e a r c h .   T h a t   s e a r c h   m a t c h e s   o n l y   t h e   c i t e   k e y ,   t h e   a u t h o r s '   s u r n a m e s   a n d   t h e   p u b l i c a t i o n ' s   t i t l e .   W a r n i n g :   i t s   r e s u l t s   m a y   b e   d i f f e r e n t   f r o m   w h a t ' s   s e e n   w h e n   u s i n g   t h e   f i l t e r   f i e l d   f o r   t h e   s a m e   t e r m .   I t   i s   m a i n l y   i n t e n d e d   f o r   a u t o c o m p l e t i o n   u s e   a n d   u s i n g   ' w h o s e '   s t a t e m e n t s   t o   s e a r c h   f o r   p u b l i c a t i o n s   s h o u l d   b e   m o r e   p o w e r f u l ,   b u t   s l o w e r .2 676 Z  ��89��:8 = ��;<; 1  ����
�� 
filt< m  ��== �>>  9 r  ��?@? m  ��AA �BB  M c C r a c k e n@ 1  ����
�� 
filt��  : r  ��CDC m  ��EE �FF  D 1  ����
�� 
filt7 GHG e  ��II 1  ����
�� 
dispH JKJ e  ��LL I ������M
�� .BDSKsrch****  @     obj ��  M ��N��
�� 
for N m  ��OO �PP  M c C r a c k e n��  K QRQ l ����ST��  S r l when writing an AppleScript for completion support in other applications use the 'for completion' parameter   T �UU �   w h e n   w r i t i n g   a n   A p p l e S c r i p t   f o r   c o m p l e t i o n   s u p p o r t   i n   o t h e r   a p p l i c a t i o n s   u s e   t h e   ' f o r   c o m p l e t i o n '   p a r a m e t e rR VWV l ����XY��  X 3 -get search for "McCracken" for completion yes   Y �ZZ Z g e t   s e a r c h   f o r   " M c C r a c k e n "   f o r   c o m p l e t i o n   y e sW [��[ l ����������  ��  ��  ��   9 o    ���� 0 thedoc theDoc 6   theDoc    7 �\\    t h e D o c 4 ]^] l ����������  ��  ��  ^ _`_ l ����ab��  a $  work again on the application   b �cc <   w o r k   a g a i n   o n   t h e   a p p l i c a t i o n` ded l ����������  ��  ��  e fgf l ����hi��  h � � the search command works also at application level. It will either search every document in that case, or the one it is addressed to.   i �jj   t h e   s e a r c h   c o m m a n d   w o r k s   a l s o   a t   a p p l i c a t i o n   l e v e l .   I t   w i l l   e i t h e r   s e a r c h   e v e r y   d o c u m e n t   i n   t h a t   c a s e ,   o r   t h e   o n e   i t   i s   a d d r e s s e d   t o .g klk I ������m
�� .BDSKsrch****  @     obj ��  m ��n��
�� 
for n m  ��oo �pp  M c C r a c k e n��  l qrq I ���st
�� .BDSKsrch****  @     obj s 4 ���u
�� 
docuu m  � ���� t ��v��
�� 
for v m  ww �xx  M c C r a c k e n��  r yzy l ��{|��  {  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.   | �}} �   A p p l e S c r i p t   l e t s   u s   e a s i l y   s e t   t h e   f i l t e r   f i e l d   i n   a l l   o p e n   d o c u m e n t s .   T h i s   i s   u s e d   i n   t h e   L a u n c h B a r   i n t e g r a t i o n   s c r i p t .z ~~ O ��� r  ��� m  �� ���  M c C r a c k e n� 1  ��
�� 
filt� 2  ��
�� 
docu ��� l ��������  ��  ��  � ��� l ������  �   GLOBAL PROPERTIES   � ��� $   G L O B A L   P R O P E R T I E S� ��� l ������  � 4 . you can get the folder where papers are filed   � ��� \   y o u   c a n   g e t   t h e   f o l d e r   w h e r e   p a p e r s   a r e   f i l e d� ��� r  &��� l "������ 1  "��
�� 
pfol��  ��  � o      ���� "0 thepapersfolder thePapersFolder� ��� l ''������  � s m it is a UNIX (i.e. POSIX) style path, so if we want to use it we should translate it into a Mac style path.    � ��� �   i t   i s   a   U N I X   ( i . e .   P O S I X )   s t y l e   p a t h ,   s o   i f   w e   w a n t   t o   u s e   i t   w e   s h o u l d   t r a n s l a t e   i t   i n t o   a   M a c   s t y l e   p a t h .  � ��� O  'Q��� Z  -P������� I -9�����
�� .coredoexbool        obj � 4  -5���
�� 
psxf� o  14���� "0 thepapersfolder thePapersFolder��  � I <L�����
�� .aevtodocnull  �    alis� c  <H��� l <D������ 4  <D���
�� 
psxf� o  @C���� "0 thepapersfolder thePapersFolder��  ��  � m  DG��
�� 
alis��  ��  ��  � m  '*���                                                                                  MACS   alis    r  Macintosh HD               ũ��H+     u
Finder.app                                                       v��R�u        ����  	                CoreServices    ũ��      �Rve       u   1   0  3Macintosh HD:System:Library:CoreServices:Finder.app    
 F i n d e r . a p p    M a c i n t o s h   H D  &System/Library/CoreServices/Finder.app  / ��  � ��� l RR��������  ��  ��  � ��� l RR������  � %  get all known types and fields   � ��� >   g e t   a l l   k n o w n   t y p e s   a n d   f i e l d s� ��� e  RX�� 1  RX��
�� 
atyp� ��� e  Y_�� 1  Y_��
�� 
afnm� ���� l ``��������  ��  ��  ��    m     ���                                                                                  BDSK   alis    �  Macintosh HD               ũ��H+   CsBibDesk.app                                                     �Q Ƭ�W        ����  	                Debug     ũ��      Ƭ�7     Cs � XR 
��  |S  EMacintosh HD:Users:hofman:Development:BuildProducts:Debug:BibDesk.app     B i b D e s k . a p p    M a c i n t o s h   H D  8Users/hofman/Development/BuildProducts/Debug/BibDesk.app  /    ��  ��  ��    ��� l     ��������  ��  ��  � ���� l     ��������  ��  ��  ��       ������  � ��
�� .aevtoappnull  �   � ****� �����������
�� .aevtoappnull  �   � ****� k    b��  ����  ��  ��  �  � O����������������������� {��������������� ����������� ����������� ���������������������o����~�������~�}�|��{�z�y=AE�xO�wow��v�u��t�s�r�q�p�o
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
�� .BDSKImptnull���     docu�� 0 newpubs newPubs
�� 
cobj
�� 
BTeX�  
�� 
ckey�� 0 somepubs somePubs
�� 
sele�� 0 theselection theSelection�� 0 thepub thePub
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
� 
fldv�~  0 nonemptyfields nonEmptyFields
�} 
gcky�| 0 	theauthor 	theAuthor�{ 0 hispubs hisPubs
�z .BDSKshownull��� ��� obj 
�y 
filt
�x 
disp
�w .BDSKsrch****  @     obj 
�v 
pfol�u "0 thepapersfolder thePapersFolder
�t 
psxf
�s .coredoexbool        obj 
�r 
alis
�q .aevtodocnull  �    alis
�p 
atyp
�o 
afnm��c�_*j O*��l O*�k/EE�O��*���*�-5� E�O��*�-6l 
E�O*�-j O�E�O*��l E` O_ a k/Ea ,EE�O*�-a [a ,\Za @1E` O_ *a ,FO*a ,E` O_ a k/EE` O*a a a _ � O*�a a a  a !l� E` "O_ �_ "l #O_ �_ "l $O*a %k/�-EO_  �*a &-a ',EO*a (-EE` )O*a *-E` +Oa ,*a -,FO*a .a //EE` 0O*a .a 1/a 2,EOa 3*a .a 4/a 2,FO*a .-a  ,EE` 5O*a ,EO*a 6,E*a ,FO*a &k/EE` 7O_ 7a  ,EOa 8�*a *-6l #OPUO*a &a 9/EE` 7O_ 7�-EE` :O_ j ;O_ 7j ;O*a <,a =  a >*a <,FY a ?*a <,FO*a @,EO*a a Al BOPUO*a a Cl BO*�k/a a Dl BO*�- a E*a <,FUO*a F,E` GOa H %*a I_ G/j J *a I_ G/a K&j LY hUO*a M,EO*a N,EOPUascr  ��ޭ