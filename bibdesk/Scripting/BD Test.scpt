FasdUAS 1.101.10   ��   ��    k             l    ��  O      	  k    
 
     l   �� ��    Y S Get first document and talk to it. Certain things won't work for the others anyway         r        n    
    4    
�� 
�� 
cobj  m    	����   2   ��
�� 
docu  o      ���� 0 d        l   ������  ��        l   �    O    �    k    �       l   ��  ��     - ' we can use whose right out of the box!      ! " ! r    " # $ # n      % & % 4     �� '
�� 
cobj ' m    ����  & l    (�� ( 6    ) * ) 2   ��
�� 
bibi * E     + , + 1    ��
�� 
ckey , m     - -  DG   ��   $ o      ���� 0 p   "  . / . l  # #������  ��   /  0 1 0 l  # #�� 2��   2 * $ THINGS WE CAN DO WITH A PUBLICATION    1  3 4 3 l  # S 5 6 5 O   # S 7 8 7 k   ' R 9 9  : ; : l  ' '�� <��   < 1 + all properties give quite a lengthy output    ;  = > = l  ' '�� ?��   ?   get properties    >  @ A @ l  ' '������  ��   A  B C B l  ' '�� D��   D � � we can access all fields, but this has to be done in a two-step process for some mysterious AppleScript reason. The keys have to be surrounded by pipes.    C  E F E r   ' , G H G 1   ' *��
�� 
flds H o      ���� 0 f   F  I J I e   - 1 K K n   - 1 L M L o   . 0���� 0 Journal   M o   - .���� 0 f   J  N O N l  2 2������  ��   O  P Q P l  2 2�� R��   R I C plurals as well as accessing a whole array of things  work as well    Q  S T S n   2 8 U V U 1   5 7��
�� 
aunm V 2  2 5��
�� 
auth T  W X W l  9 9������  ��   X  Y Z Y l  9 9�� [��   [ - ' as does access to the local file's URL    Z  \ ] \ l  9 9�� ^��   ^ | v This is nice but the whole differences between Unix and traditional AppleScript style paths seem to make it worthless    ]  _ ` _ r   9 > a b a 1   9 <��
�� 
lURL b o      ���� 0 lf   `  c d c l  ? ?������  ��   d  e f e l  ? ?�� g��   g #  we can easily set properties    f  h i h r   ? H j k j m   ? B l l  http://localhost/lala/    k 1   B G��
�� 
rURL i  m n m l  I I������  ��   n  o p o l  I I�� q��   q + % and get the underlying BibTeX record    p  r�� r r   I R s t s 1   I N��
�� 
BTeX t o      ���� 0 bibtexrecord BibTeXRecord��   8 o   # $���� 0 p   6   p    4  u v u l  T T������  ��   v  w x w l  T T�� y��   y + % GENERATING AND DELETING PUBLICATIONS    x  z { z l  T T�� |��   |   let's make a new record    {  } ~ } r   T j  �  I  T f���� �
�� .corecrel****      � null��   � �� � �
�� 
kocl � m   X Y��
�� 
bibi � �� ���
�� 
insh � l  \ ` ��� � n   \ ` � � �  ;   _ ` � 2  \ _��
�� 
bibi��  ��   � o      ���� 0 n   ~  � � � l  k k�� ���   � ? 9 this is initially empty, so fill it with a BibTeX string    �  � � � r   k v � � � o   k n���� 0 bibtexrecord BibTeXRecord � n       � � � 1   q u��
�� 
BTeX � o   n q���� 0 n   �  � � � l  w w�� ���   �    get rid of the new record    �  � � � I  w ~�� ���
�� .coredelonull��� ��� obj  � o   w z���� 0 n  ��   �  � � � l   ������  ��   �  � � � l   �� ���   � !  MANIPULATING THE SELECTION    �  � � � l   �� ���   � L F Play with the selection and put styled bibliography on the clipboard.    �  � � � r    � � � � 6   � � � � 2   ���
�� 
bibi � E   � � � � � 1   � ���
�� 
ckey � m   � � � �  DG    � o      ���� 0 ar   �  � � � r   � � � � � o   � ����� 0 ar   � 1   � ���
�� 
sele �  � � � I  � �������
�� .BDSKsbtcnull��� ��� obj ��  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   �   FILTERING AND SEARCHING    �  � � � l  � ��� ���   � y s We can get and set the filter field of each document and get the list of publications that is currently displayed.    �  � � � l  � ��� ���   ���In addition there is the search command which returns the results of a search. That search matches only the cite key, the authors' surnames and the publication's title. Warning: its results may be different from what's seen when using the filter field for the same term. It is mainly intended for autocompletion use and using 'whose' statements to search for publications should be more powerful, but slower.    �  � � � Z   � � � ��� � � =  � � � � � 1   � ���
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
for  � m   � � � �  gerbe   ��   �  � � � l  � ��� ���   � r l When writing an AppleScript for completion support in other applications use the 'for completion' parameter    �  � � � e   � � � � I  � ����� �
�� .BDSKsrchlist    ��� obj ��   � �� � �
�� 
for  � m   � � � �  gerbe    � �� ���
�� 
cmpl � m   � ���
�� savoyes ��   �  ��� � l  � �������  ��  ��    o    ���� 0 d      d      � � � l  � �������  ��   �  � � � l  � ��� ���   � � � The search command works also at application level. It will either search every document in that case, or the one it is addressed to.    �  � � � I  � ����� �
�� .BDSKsrchlist    ��� obj ��   � �� ���
�� 
for  � m   � � � �  gerbe   ��   �  � � � I  ��� � �
�� .BDSKsrchlist    ��� obj  � 4  � ��� �
�� 
docu � m   � �����  � �� ���
�� 
for  � m   � �  gerbe   ��   �  � � � l 		�� ���   �  y AppleScript lets us easily set the filter field in all open documents. This is used in the LaunchBar integration script.    �  ��� � O 	 � � � r   � � � m   � � 
 chen    � 1  ��
�� 
filt � 2  	��
�� 
docu��   	 m      � ��null     ߀�� KvBibdesk.app�� �0�L��� 7���@   @ ��   )       �(�K� ���` �BDSK   alis    b  Kalle                      |%�JH+   KvBibdesk.app                                                     {Խ"A        ����  	                builds    |%�:      �!�!     Kv d� %�  "E  ,Kalle:Users:ssp:Developer:builds:Bibdesk.app    B i b d e s k . a p p    K a l l e  &Users/ssp/Developer/builds/Bibdesk.app  /    
��  ��     � � � l     ������  ��   �  ��� � l     �����  �  ��       �~ � ��~   � �}
�} .aevtoappnull  �   � **** � �| ��{�z � ��y
�| .aevtoappnull  �   � **** � k     � �  �x�x  �{  �z   �   � , ��w�v�u�t �s -�r�q�p�o�n�m�l�k l�j�i�h�g�f�e�d�c�b ��a�`�_�^ � � ��]�\ ��[ ��Z�Y � � �
�w 
docu
�v 
cobj�u 0 d  
�t 
bibi   
�s 
ckey�r 0 p  
�q 
flds�p 0 f  �o 0 Journal  
�n 
auth
�m 
aunm
�l 
lURL�k 0 lf  
�j 
rURL
�i 
BTeX�h 0 bibtexrecord BibTeXRecord
�g 
kocl
�f 
insh�e 
�d .corecrel****      � null�c 0 n  
�b .coredelonull��� ��� obj �a 0 ar  
�` 
sele
�_ .BDSKsbtcnull��� ��� obj 
�^ 
filt
�] 
disp
�\ 
for 
�[ .BDSKsrchlist    ��� obj 
�Z 
cmpl
�Y savoyes �y�*�-�k/E�O� �*�-�[�,\Z�@1�k/E�O� -*�,E�O��,EO*�-�,EO*�,E�Oa *a ,FO*a ,E` UO*a �a *�-6a  E` O_ _ a ,FO_ j O*�-�[�,\Za @1E` O_ *a ,FO*j O*a ,a   a  *a ,FY a !*a ,FO*a ",EO*a #a $l %O*a #a &a 'a (a  %OPUO*a #a )l %O*�k/a #a *l %O*�- a +*a ,FUU ascr  ��ޭ