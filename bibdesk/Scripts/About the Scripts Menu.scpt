FasdUAS 1.101.10   ��   ��    k             l     �� ��    O I Install in bundle/Contents/Scripts so it's visible from the Scripts menu       	  l     �� 
��   
 e _ This script was shipped with OmniWeb5.  Stefan K. from Omni said that we can treat this script    	     l     �� ��    9 3 as if it is covered under the Omni Source License.         l     ������  ��        j     �� �� 0 appname AppName  m         BibDesk         l     ������  ��        l    	    r     	    I    ��  
�� .earsffdralis        afdr  m        
 asup     �� ��
�� 
from  m    ��
�� fldmfldu��    o      ���� 0 
asupfolder 
asupFolder  B < "asup" = application support folder... buggy standard osax.        !   l  
  "�� " r   
  # $ # b   
  % & % n   
  ' ( ' 1    ��
�� 
psxp ( o   
 ���� 0 
asupfolder 
asupFolder & o    ���� 0 appname AppName $ o      ����  0 asupfolderpath asupFolderPath��   !  ) * ) l     ������  ��   *  + , + l   1 -�� - r    1 . / . b    / 0 1 0 b    - 2 3 2 b    ' 4 5 4 b    % 6 7 6 b     8 9 8 b     : ; : m     < < 0 *This menu contains AppleScripts to extend     ; o    ���� 0 appname AppName 9 m     = = � �'s functionality. To run a script, select it in the menu. To view a script in Script Editor, Option-click it in the menu. To add scripts to the menu, save them in your Library/Application Support/    7 o    $���� 0 appname AppName 5 m   % & > >  /Scripts folder. See     3 o   ' ,���� 0 appname AppName 1 m   - . ? ? !  Help for more information.    / o      ���� 0 
dialogtext 
dialogText��   ,  @ A @ l     ������  ��   A  B C B l  2 B D�� D I  2 B�� E F
�� .sysodlogaskr        TEXT E o   2 3���� 0 
dialogtext 
dialogText F �� G H
�� 
btns G J   4 8 I I  J K J m   4 5 L L  Open Scripts Folder    K  M�� M m   5 6 N N  OK   ��   H �� O��
�� 
dflt O m   9 < P P  OK   ��  ��   C  Q R Q l  C N S�� S r   C N T U T l  C J V�� V n   C J W X W 1   F J��
�� 
bhit X l  C F Y�� Y 1   C F��
�� 
rslt��  ��   U o      ����  0 buttonreturned buttonReturned��   R  Z [ Z l     ������  ��   [  \ ] \ l  O ^�� ^ Z   O _ `���� _ =  O V a b a o   O R����  0 buttonreturned buttonReturned b m   R U c c  Open Scripts Folder    ` k   Y d d  e f e l  Y Y������  ��   f  g h g l  Y Y�� i��   i ? 9 find out if the folder exists or if we have to create it    h  j k j r   Y ^ l m l m   Y Z��
�� boovfals m o      ���� (0 shouldcreatefolder shouldCreateFolder k  n o n r   _ h p q p b   _ d r s r o   _ `����  0 asupfolderpath asupFolderPath s m   ` c t t  /Scripts    q o      ���� &0 scriptsfolderpath scriptsFolderPath o  u v u Q   i � w x y w n   l } z { z 1   x |��
�� 
asdr { l  l x |�� | I  l x�� }��
�� .sysonfo4asfe       **** } 4   l t�� ~
�� 
psxf ~ o   p s���� &0 scriptsfolderpath scriptsFolderPath��  ��   x R      ������
�� .ascrerr ****      � ****��  ��   y r   � �  �  m   � ���
�� boovtrue � o      ���� (0 shouldcreatefolder shouldCreateFolder v  � � � l  � �������  ��   �  � � � l  � ��� ���   � n h ask if we should create the folder, and create it via the shell for quick rescursive directory creation    �  � � � Z   � � � ����� � o   � ����� (0 shouldcreatefolder shouldCreateFolder � k   � � � �  � � � I  � ��� ���
�� .sysodlogaskr        TEXT � m   � � � � � |That Scripts folder doesn't exist yet. Would you like to create it now? (You may be prompted for an administrator password.)   ��   �  ��� � Q   � � � � � � k   � � � �  � � � I  � ��� ���
�� .sysoexecTEXT���     TEXT � b   � � � � � b   � � � � � m   � � � �  
mkdir -p '    � o   � ����� &0 scriptsfolderpath scriptsFolderPath � m   � � � �  '   ��   �  ��� � r   � � � � � m   � ���
�� boovfals � o      ���� (0 shouldcreatefolder shouldCreateFolder��   � R      ������
�� .ascrerr ****      � ****��  ��   � Q   � � � � � � k   � � � �  � � � I  � ��� � �
�� .sysoexecTEXT���     TEXT � b   � � � � � b   � � � � � m   � � � �  	mkdir -p     � o   � ����� &0 scriptsfolderpath scriptsFolderPath � m   � � � �  '    � �� ���
�� 
badm � m   � ���
�� boovtrue��   �  � � � r   � � � � � m   � ���
�� boovfals � o      ���� (0 shouldcreatefolder shouldCreateFolder �  ��� � l  � �������  ��  ��   � R      ������
�� .ascrerr ****      � ****��  ��   � I  � ��� � �
�� .sysodlogaskr        TEXT � m   � � � � F @You do not have sufficent user privileges to create this folder.    � �� � �
�� 
btns � m   � � � �  OK    � �� ���
�� 
dflt � m   � � � �  OK   ��  ��  ��  ��   �  � � � l  � �������  ��   �  � � � l  � ��� ���   � ] W open the folder for the user using the Finder (or user's preferred Finder replacement)    �  � � � Z  � � ����� � H   � � � � o   � ����� (0 shouldcreatefolder shouldCreateFolder � I  ��� ���
�� .sysoexecTEXT���     TEXT � b   � � � � b   � � � � m   � � � �  open '    � o   ����� &0 scriptsfolderpath scriptsFolderPath � m   � �  '   ��  ��  ��   �  ��� � l ������  ��  ��  ��  ��  ��   ]  ��� � l     ������  ��  ��       �� �  ���   � ������ 0 appname AppName
�� .aevtoappnull  �   � **** � �� ����� � ���
�� .aevtoappnull  �   � **** � k     � �   � �    � �  + � �  B � �  Q � �  \����  ��  ��   �   � + ����������� < = > ?�~�} L N�| P�{�z�y�x�w c�v t�u�t�s�r�q�p � � ��o � ��n � � � � �
�� 
from
�� fldmfldu
�� .earsffdralis        afdr�� 0 
asupfolder 
asupFolder
�� 
psxp�  0 asupfolderpath asupFolderPath�~ 0 
dialogtext 
dialogText
�} 
btns
�| 
dflt�{ 
�z .sysodlogaskr        TEXT
�y 
rslt
�x 
bhit�w  0 buttonreturned buttonReturned�v (0 shouldcreatefolder shouldCreateFolder�u &0 scriptsfolderpath scriptsFolderPath
�t 
psxf
�s .sysonfo4asfe       ****
�r 
asdr�q  �p  
�o .sysoexecTEXT���     TEXT
�n 
badm�����l E�O��,b   %E�O�b   %�%b   %�%b   %�%E�O����lv�a a  O_ a ,E` O_ a   �fE` O�a %E` O *a _ /j a ,EW X  eE` O_  da j O a  _ %a !%j "OfE` W >X    a #_ %a $%a %el "OfE` OPW X  a &�a '�a (a  Y hO_  a )_ %a *%j "Y hOPY hascr  ��ޭ