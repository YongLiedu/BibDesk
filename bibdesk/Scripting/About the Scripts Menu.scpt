FasdUAS 1.101.10   ��   ��    k             l     �� ��    O I Install in bundle/Contents/Scripts so it's visible from the Scripts menu       	  l     ������  ��   	  
  
 j     �� �� 0 appname AppName  m         BibDesk         l     ������  ��        l     ��  r         b         b         b         b         b     	    b          m      ! ! 0 *This menu contains AppleScripts to extend       o    ���� 0 appname AppName  m     " " � �'s functionality; to run a script, select it in the menu. To add scripts to the menu, save them in your Library/Application Support/     o   	 ���� 0 appname AppName  m     # #  /Scripts folder. See      o    ���� 0 appname AppName  m     $ $   Help for more info.     o      ���� 0 
dialogtext 
dialogText��     % & % l     ������  ��   &  ' ( ' l   ( )�� ) I   (�� * +
�� .sysodlogaskr        TEXT * o    ���� 0 
dialogtext 
dialogText + �� , -
�� 
btns , J    " . .  / 0 / m     1 1  Open Scripts Folder    0  2�� 2 m      3 3  OK   ��   - �� 4��
�� 
dflt 4 m   # $ 5 5  OK   ��  ��   (  6 7 6 l     ������  ��   7  8�� 8 l  )� 9�� 9 Z   )� : ;���� : =  ) . < = < n   ) , > ? > 1   * ,��
�� 
bhit ? l  ) * @�� @ 1   ) *��
�� 
rslt��   = m   , - A A  Open Scripts Folder    ; k   1� B B  C D C l  1 1������  ��   D  E F E l  1 @ G H G r   1 @ I J I I  1 <�� K L
�� .earsffdralis        afdr K m   1 2 M M 
 asup    L �� N��
�� 
from N m   5 8��
�� fldmfldu��   J o      ����  0 userasupfolder userAsupFolder H B < "asup" = application support folder... buggy standard osax.    F  O P O r   A R Q R Q I  A N�� S T
�� .earsffdralis        afdr S m   A D U U 
 asup    T �� V��
�� 
from V m   G J��
�� fldmfldl��   R o      ���� "0 localasupfolder localAsupFolder P  W X W Q   S v Y Z [ Y l  V g \ ] \ r   V g ^ _ ^ I  V c�� ` a
�� .earsffdralis        afdr ` m   V Y b b 
 dlib    a �� c��
�� 
from c m   \ _��
�� fldmfldn��   _ o      ���� &0 networkdlibfolder networkDlibFolder ] E ? "dlib" = library folder, since asup folder might not exist yet    Z R      ������
�� .ascrerr ****      � ****��  ��   [ r   o v d e d m   o r f f       e o      ���� &0 networkdlibfolder networkDlibFolder X  g h g l  w w������  ��   h  i j i Z   w � k l�� m k =  w ~ n o n o   w z���� &0 networkdlibfolder networkDlibFolder o m   z } p p       l k   � � q q  r s r I  � ��� t u
�� .sysodlogaskr        TEXT t m   � � v v � �There are two different folders you can put scripts into, depending on whether you want to keep them to yourself or share them with other people who have user accounts on this computer. Which do you want to open?    u �� w��
�� 
btns w J   � � x x  y z y m   � � { {  	My Folder    z  |�� | m   � � } }  Computer Folder   ��  ��   s  ~�� ~ r   � �  �  n   � � � � � 1   � ���
�� 
bhit � l  � � ��� � 1   � ���
�� 
rslt��   � o      ���� 0 dialogreply dialogReply��  ��   m k   � � � �  � � � I  � ��� � �
�� .sysodlogaskr        TEXT � m   � � � � � �There are three different folders you can put scripts into, depending on whether you want to keep them to yourself, share them with users on this computer, or share them with all users on your network. Which do you want to open?    � �� ���
�� 
btns � J   � � � �  � � � m   � � � �  	My Folder    �  � � � m   � � � �  Computer Folder    �  ��� � m   � � � �  Network Folder   ��  ��   �  ��� � r   � � � � � n   � � � � � 1   � ���
�� 
bhit � l  � � ��� � 1   � ���
�� 
rslt��   � o      ���� 0 dialogreply dialogReply��   j  � � � Z   � � � � � � � =  � � � � � o   � ����� 0 dialogreply dialogReply � m   � � � �  	My Folder    � r   � � � � � o   � �����  0 userasupfolder userAsupFolder � o      ���� 0 chosenfolder chosenFolder �  � � � =  � � � � � o   � ����� 0 dialogreply dialogReply � m   � � � �  Computer Folder    �  ��� � r   � � � � � o   � ����� "0 localasupfolder localAsupFolder � o      ���� 0 chosenfolder chosenFolder��   � r   � � � � � o   � ����� &0 networkdlibfolder networkDlibFolder � o      ���� 0 chosenfolder chosenFolder �  � � � l  � �������  ��   �  � � � l  � ��� ���   � ? 9 find out if the folder exists or if we have to create it    �  � � � r   � � � � � m   � ���
�� boovfals � o      ���� (0 shouldcreatefolder shouldCreateFolder �  � � � Z   �) � ��� � � =  � � � � � o   � ����� 0 chosenfolder chosenFolder � o   � ����� &0 networkdlibfolder networkDlibFolder � r   � � � � b   � � � � b   �	 � � � b   � � � � n   � � � � � 1   � ���
�� 
psxp � o   � ����� 0 chosenfolder chosenFolder � m   � � �  Application Support/    � o  ���� 0 appname AppName � m  	 � �  /Scripts    � o      ���� &0 scriptsfolderpath scriptsFolderPath��   � r  ) � � � b  % � � � b  ! � � � n   � � � 1  ��
�� 
psxp � o  ���� 0 chosenfolder chosenFolder � o   ���� 0 appname AppName � m  !$ � �  /Scripts    � o      ���� &0 scriptsfolderpath scriptsFolderPath �  � � � Q  *K � � � � n  -> � � � 1  9=��
�� 
asdr � l -9 ��� � I -9�� ���
�� .sysonfo4asfe       **** � 4  -5�� �
�� 
psxf � o  14���� &0 scriptsfolderpath scriptsFolderPath��  ��   � R      ������
�� .ascrerr ****      � ****��  ��   � r  FK � � � m  FG��
�� boovtrue � o      ���� (0 shouldcreatefolder shouldCreateFolder �  � � � l LL������  ��   �  � � � l LL�� ���   � n h ask if we should create the folder, and create it via the shell for quick rescursive directory creation    �  � � � Z  L� � ����� � o  LO���� (0 shouldcreatefolder shouldCreateFolder � k  R� � �  � � � I RY�� ���
�� .sysodlogaskr        TEXT � m  RU � � � |That Scripts folder doesn't exist yet. Would you like to create it now? (You may be prompted for an administrator password.)   ��   �  ��� � Q  Z� � � � � k  ]r � �  � � � I ]l�� ���
�� .sysoexecTEXT���     TEXT � b  ]h � � � b  ]d � � � m  ]` � �  
mkdir -p '    � o  `c���� &0 scriptsfolderpath scriptsFolderPath � m  dg � �  '   ��   �  ��� � r  mr � � � m  mn��
�� boovfals � o      ���� (0 shouldcreatefolder shouldCreateFolder��   � R      ������
�� .ascrerr ****      � ****��  ��   � Q  z� �  � k  }�  I }���
�� .sysoexecTEXT���     TEXT b  }� b  }�	
	 m  }�  	mkdir -p    
 o  ���� &0 scriptsfolderpath scriptsFolderPath m  ��  '    �~�}
�~ 
badm m  ���|
�| boovtrue�}    r  �� m  ���{
�{ boovfals o      �z�z (0 shouldcreatefolder shouldCreateFolder �y l ���x�w�x  �w  �y    R      �v�u�t
�v .ascrerr ****      � ****�u  �t   I ���s
�s .sysodlogaskr        TEXT m  �� F @You do not have sufficent user privileges to create this folder.    �r
�r 
btns m  ��  OK    �q�p
�q 
dflt m  ��  OK   �p  ��  ��  ��   �  l ���o�n�o  �n    l ���m�m   ] W open the folder for the user using the Finder (or user's preferred Finder replacement)     !  Z ��"#�l�k" H  ��$$ o  ���j�j (0 shouldcreatefolder shouldCreateFolder# I ���i%�h
�i .sysoexecTEXT���     TEXT% b  ��&'& b  ��()( m  ��**  open '   ) o  ���g�g &0 scriptsfolderpath scriptsFolderPath' m  ��++  '   �h  �l  �k  ! ,�f, l ���e�d�e  �d  �f  ��  ��  ��  ��       �c- .�c  - �b�a�b 0 appname AppName
�a .aevtoappnull  �   � ****. �`/�_�^01�]
�` .aevtoappnull  �   � ****/ k    �22  33  '44  8�\�\  �_  �^  0  1 > ! " # $�[�Z 1 3�Y 5�X�W�V�U A M�T�S�R�Q U�P�O b�N�M�L�K f p v { }�J � � � � ��I ��H�G � ��F ��E�D�C � � ��B�A*+�[ 0 
dialogtext 
dialogText
�Z 
btns
�Y 
dflt�X 
�W .sysodlogaskr        TEXT
�V 
rslt
�U 
bhit
�T 
from
�S fldmfldu
�R .earsffdralis        afdr�Q  0 userasupfolder userAsupFolder
�P fldmfldl�O "0 localasupfolder localAsupFolder
�N fldmfldn�M &0 networkdlibfolder networkDlibFolder�L  �K  �J 0 dialogreply dialogReply�I 0 chosenfolder chosenFolder�H (0 shouldcreatefolder shouldCreateFolder
�G 
psxp�F &0 scriptsfolderpath scriptsFolderPath
�E 
psxf
�D .sysonfo4asfe       ****
�C 
asdr
�B .sysoexecTEXT���     TEXT
�A 
badm�]��b   %�%b   %�%b   %�%E�O����lv��� O��,� ��a a l E` Oa a a l E` O a a a l E` W X  a E` O_ a   a �a a  lvl O��,E` !Y a "�a #a $a %mvl O��,E` !O_ !a &  _ E` 'Y _ !a (  _ E` 'Y 	_ E` 'OfE` )O_ '_   _ 'a *,a +%b   %a ,%E` -Y _ 'a *,b   %a .%E` -O *a /_ -/j 0a 1,EW X  eE` )O_ ) ba 2j O a 3_ -%a 4%j 5OfE` )W <X    a 6_ -%a 7%a 8el 5OfE` )OPW X  a 9�a :�a ;� Y hO_ ) a <_ -%a =%j 5Y hOPY h ascr  ��ޭ