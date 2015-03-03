#!/bin/bash
# Script para instalar Hadoop
#

#########################################################
# Variables para el usuario, grupo, programa, y version
#########################################################
user="hadoop3"
group="hadoop3"
program="hadoop"
version="2.6.0"
home_user="/home/$user"
etc_hadoop="$home_user/$program-$version/etc/hadoop"

###Verificar usuario
if (( $EUID != 0 )); then
	echo "Error: Permiso denegado para correr este Script"
	exit 1
fi

##################################
#Creacion del nuevo usuario hadoop
##################################
echo "Creando usuario $user"
useradd -d /home/$user -m $user
echo "Password del usuario"
passwd $user

echo "Creando grupo $group"
groupadd $group
echo "Agregando el usuario $user al grupo $group"
#adduser $user $group
usermod -a -G $user $group

#########################################
# Entrando al nuevo usuario para
# configurar el ssh, desde script externo
#########################################
#su $user ./conexion_ssh.sh

##################################################
###ssh-keygen -t rsa
###cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
###chmod 0600 ~/.ssh/authorized_keys
##################################################

#Entrando al directorio home de hadoop
cd $home_user
pwd

#getting the download of hadoop
if [[ ! -f "$program-$version.tar.gz" ]]; then
	echo "Downloading $program-$version.tar.gz"
	#wget http://apache.claz.org/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz
	wget http://apache.claz.org/hadoop/common/$program-$version/$program-$version.tar.gz

	#Verificar que el tar se haya descargado antes de descomprimirlo
	if [[ $? != 0 ]]; then
		#echo "El archivo $program-$version.tar.gz no existe"
		echo "Error: al descargar $program-$version !!!"
		exit 1
	fi
fi

echo "DESCOMPRIMIENDO HADOOP"
#tar xzf hadoop-2.6.0.tar.gz
tar xzf "$program-$version.tar.gz"

if [[ $? != 0 ]]; then
	echo "Error: No se puede descomprimir correctamente $program-$version"
	exit 1
fi

#######################################
#Colocar las variables de entorno en el .bash
#######################################
verificar_variables() {

file_bash="/home/$user/.bashrc"

echo "VERIFICANDO VARIABLES DE ENTORNO"
for i in $@; do
	#
	cat $file_bash | grep -i $i >> /dev/null
	# or echo $i 

	if [ $? != 0 ]; then
		#echo "La variable $i No esta en el archivo"
		#echo ""
		if [ $i = $HADOOP_HOME ]; then
			echo "export $i=/home/$user/hadoop-$version" >> $file_bash
		elif [ $i = hp_common_lib ]; then
			echo "export $i=\$$HADOOP_HOME/lib/native" >> $file_bash
		else
			echo "export $i=\$$HADOOP_HOME" >> $file_bash
		fi
		echo "variable $i exportada a $file_bash..."
	else
		#echo "La variable $i Esta en el archivo"
		echo "Variable de entorno $i encontrada en $file_bash omitiendola..."
	fi

done

#if [[ $JAVA_HOME ]]; then
#	echo "export JAVA_HOME=$JAVA_HOME" >> file_bash
#fi

echo "export PATH=\$PATH:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin" >> $file_bash

} #fin de funcion

HADOOP_HOME="HADOOP_HOME"
hp_install=HADOOP_INSTALL
hp_mapred=HADOOP_MAPRED
hp_common_home=HADOOP_COMMON_HOME
hp_hdfs=HADOOP_HDFS_HOME
yarn_home=YARN_HOME
hp_common_lib=HADOOP_COMMON_LIB_NATIVE_DIR

verificar_variables $HADOOP_HOME $hp_install $hp_mapred $hp_common_home $hp_hdfs $yarn_home $hp_common_lib

echo "Haciendo Source al archivo bash"
source $home_user/.bashrc

##############################################################
# Modificar los archivos de configuracion
# core-site.xml, hdfs-site.xml, yarn-site.xml, mapred-site.xml
#
##############################################################
hadoop_etc="/home/$user/hadoop-$version/etc/hadoop/"
#echo "DIRECTORIO DE CONFIGURACION ETC = $hadoop_etc"

###########################
# Archivos a modificar
###########################
file_core_site="core-site.xml"
file_hdfs_site="hdfs-site.xml"
file_yarn_site="yarn-site.xml"
file_mapred_site="mapred-site.xml"

cd $hadoop_etc
#entrando al directorio de configuracion hadoop-version/etc/hadoop/
if [[ $? != 0 ]]; then
	echo "Error: imposible acceder al directorio $hadoop_etc !"
	exit 1
fi

echo "MODIFICANDO LOS ARCHIVOS DE CONFIGURACION"

########################################################
#reemplazo de etiquetas </configuration> con identacion
########################################################
property="\n\t<property>"
name="\n\t\t<name>"
value="\n\t\t<value>"
close_name="<\/name>"
close_value="<\/value>"
close_property="\n\t<\/property>"
close_configuration="\n<\/configuration>\n"

###################################################################
# Funcion:
# para verificar que la propiedad $1 esta en el archivo de conf.$2
# $1 nombre de la propiedad a buscar
# $2 el archivo en el que buscar la propiedad
# $3 texto completo a ingresar
###################################################################
check_property() {
	#verificar la existencia del archivo
	if [[ -f $2 ]]; then
		
		cat $2 | grep -i $1 >> /dev/null	
		#verificamos la existencia de la propiedad
		if [[ $? != 0 ]]; then
			#la propiedad NO esta en el archivo
			echo "la propiedad NO esta en el archivo"
			#agregamos la propiedad completa al archivo
			sed -i "s/<\/configuration>/$3/" $2
			else
			#la propiedad Si esta en el archivo
			echo "la propiedad SI esta en el archivo"
		fi
	fi
}

##################################################
# valores a agregar en el archivo de configuracion
# core-site.xml
##################################################

name_core="fs.default.name"
value_core="hdfs:\/\/localhost:9000"
property1=$property$name$name_core$close_name$value$value_core$close_value$close_property$close_configuration

check_property $name_core $file_core_site $property1

##################################################
# valores a agregar en el archivo de configuracion
# hdfs-site.xml
##################################################

name_hdfs_1="dfs.replication"
value_hdfs_1="1"
property1=$property$name$name_hdfs_1$close_name$value$value_hdfs_1$close_value$close_property$close_configuration

check_property $name_hdfs_1 $file_hdfs_site $property1

name_hdfs_2="dfs.name.dir"
value_hdfs_2="file:\/\/\/home\/hadoop\/hadoopdata\/hdfs\/namenode"
property2=$property$name$name_hdfs_2$close_name$value$value_hdfs_2$close_value$close_property$close_configuration

check_property $name_hdfs_2 $file_hdfs_site $property2

name_hdfs_3="dfs.data.dir"
value_hdfs_3="file:\/\/\/home\/hadoop\/hadoopdata\/hdfs\/datanode"
property3=$property$name$name_hdfs_3$close_name$value$value_hdfs_3$close_value$close_property$close_configuration

check_property $name_hdfs_3 $file_hdfs_site $property3

################################################################################
# valores a agregar en el archivo de configuracion
# mapred-site.xml
# Verificar que este el archivo, sino copiarlo desde el mapred-site.xml.template
################################################################################

if [ ! -f $file_mapred_site ]; then
	echo "Creando archivo de configuracion $file_mapred_site"
	cp mapred-site.xml.template	mapred-site.xml
fi

name_mapred="mapreduce.framework.name"
value_mapred="yarn"
property1=$property$name$name_mapred$close_name$value$value_mapred$close_value$close_property$close_configuration

check_property $name_mapred $file_mapred_site $property1

##################################################
# valores a agregar en el archivo de configuracion
# yarn-site.xml
##################################################

name_yarn="yarn.nodemanager.aux-services"
value_yarn="mapreduce_shuffle"
property1=$property$name$name_yarn$close_name$value$value_yarn$close_value$close_property$close_configuration

check_property $name_yarn $file_yarn_site $property1

echo "finished of configurating files"


#################################
# Exportar la variable $JAVA_HOME
#################################
echo $JAVA_HOME
file_hadoop_env="hadoop-env.sh"
if [[ -n $JAVA_HOME ]]; then
	echo "OK: JAVA_HOME found in $JAVA_HOME"
else
	echo "Error: JAVA_HOME not found"
	#java=$(which java)
fi

if [ -f $file_hadoop_env ]; then
	echo "Exportando java en el archivo $file_hadoop_env"
	sed -i 's/{JAVA_HOME}/JAVA_HOME/' $file_hadoop_env
fi

#Entrar al home del usuario
cd $home_user
#cambiar los archivos al user correcto
chown -R $user:$group $program-$version

echo "End of Script"