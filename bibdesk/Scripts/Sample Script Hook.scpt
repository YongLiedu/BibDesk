FasdUAS 1.101.10   ��   ��    k             l      ��  ��    � �
This script is an example of a script hook handler for Bibdesk. 
It shows a dialog with the properties of the script hook 
and the cite keys of the publications.
     � 	 	F 
 T h i s   s c r i p t   i s   a n   e x a m p l e   o f   a   s c r i p t   h o o k   h a n d l e r   f o r   B i b d e s k .   
 I t   s h o w s   a   d i a l o g   w i t h   t h e   p r o p e r t i e s   o f   t h e   s c r i p t   h o o k   
 a n d   t h e   c i t e   k e y s   o f   t h e   p u b l i c a t i o n s . 
   
  
 l     ��������  ��  ��        w          i         I     ��  
�� .BDSKpActnull���    bibi  o      ���� 0 thepubs thePubs  �� ��
�� 
fshk  o      ���� 0 thescripthook theScriptHook��    k     x       r         e        n         1    ��
�� 
pnam  o     ���� 0 thescripthook theScriptHook  o      ���� 0 thename theName      r         e     ! ! n     " # " 1    
��
�� 
ID   # o    ���� 0 thescripthook theScriptHook   o      ���� 0 theid theID   $ % $ r     & ' & e     ( ( n     ) * ) 1    ��
�� 
fnam * o    ���� 0 thescripthook theScriptHook ' o      ���� 0 thefield theField %  + , + r     - . - e     / / n     0 1 0 1    ��
�� 
oVal 1 o    ���� 0 thescripthook theScriptHook . o      ���� 0 	oldvalues 	oldValues ,  2 3 2 r    " 4 5 4 e      6 6 n      7 8 7 1    ��
�� 
nVal 8 o    ���� 0 thescripthook theScriptHook 5 o      ���� 0 	newvalues 	newValues 3  9 : 9 r   # ' ; < ; J   # %����   < o      ���� 0 thekeys theKeys :  = > = X   ( D ?�� @ ? r   8 ? A B A e   8 < C C n   8 < D E D 1   9 ;��
�� 
ckey E o   8 9���� 0 apub aPub B l      F���� F n       G H G  ;   = > H o   < =���� 0 thekeys theKeys��  ��  �� 0 apub aPub @ o   + ,���� 0 thepubs thePubs >  I�� I I  E x�� J K
�� .sysodlogaskr        TEXT J b   E f L M L b   E d N O N b   E b P Q P b   E ` R S R b   E ^ T U T b   E \ V W V b   E Z X Y X b   E X Z [ Z b   E V \ ] \ b   E T ^ _ ^ b   E R ` a ` b   E P b c b b   E N d e d b   E L f g f b   E J h i h b   E H j k j m   E F l l � m m  N a m e :   k o   F G���� 0 thename theName i o   H I��
�� 
ret  g m   J K n n � o o  I D :   e o   L M���� 0 theid theID c o   N O��
�� 
ret  a m   P Q p p � q q  C i t e   K e y s :   _ o   R S���� 0 thekeys theKeys ] o   T U��
�� 
ret  [ m   V W r r � s s  F i e l d   n a m e :   Y o   X Y���� 0 thefield theField W o   Z [��
�� 
ret  U m   \ ] t t � u u  O l d   v a l u e s :   S o   ^ _���� 0 	oldvalues 	oldValues Q o   ` a��
�� 
ret  O m   b c v v � w w  N e w   v a l u e s :   M o   d e���� 0 	newvalues 	newValues K �� x y
�� 
btns x J   i n z z  {�� { m   i l | | � } }  O K��   y �� ~��
�� 
dflt ~ m   q r���� ��  ��   �                                                                                  BDSK   alis    �  Macintosh HD               ��GH+  I6LBibDesk.app                                                    8-��l�        ����  	                Debug     ��7      �Pc    I6LI6KI�IO@�7  EMacintosh HD:Users:hofman:Development:BuildProducts:Debug:BibDesk.app     B i b D e s k . a p p    M a c i n t o s h   H D  8Users/hofman/Development/BuildProducts/Debug/BibDesk.app  /    ��     ��  l     ��������  ��  ��  ��       �� � ���   � ��
�� .BDSKpActnull���    bibi � �� ���� � ���
�� .BDSKpActnull���    bibi�� 0 thepubs thePubs�� ������
�� 
fshk�� 0 thescripthook theScriptHook��   � 	�������������������� 0 thepubs thePubs�� 0 thescripthook theScriptHook�� 0 thename theName�� 0 theid theID�� 0 thefield theField�� 0 	oldvalues 	oldValues�� 0 	newvalues 	newValues�� 0 thekeys theKeys�� 0 apub aPub � ������������������ l�� n p r t v�� |������
�� 
pnam
�� 
ID  
�� 
fnam
�� 
oVal
�� 
nVal
�� 
kocl
�� 
cobj
�� .corecnte****       ****
�� 
ckey
�� 
ret 
�� 
btns
�� 
dflt�� 
�� .sysodlogaskr        TEXT�� y��,EE�O��,EE�O��,EE�O��,EE�O��,EE�OjvE�O �[��l kh ��,E�6F[OY��O�%�%�%�%�%�%�%�%�%�%�%�%�%�%�%�%a a kva ka   ascr  ��ޭ