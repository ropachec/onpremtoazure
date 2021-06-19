#!/bin/bash

# Script criado para a movimentação de arquivos para o Azure - Blob
# Script criado em: 2021/06/18
# Script criado por: Rogerio Pacheco

# Carrega o arquivo de propriedades
# Se o arquivo não existir encerra o script com a saida de erro de arquivo não existe
# Caso o arquivo exista, carrega o mesmo para dentro do script

PFHOME="/u01/empresa/profiles"
PFFILE="profile.properties"

if [ ! -f ${PFHOME}/${PFFILE} ];then

	echo -e "\n [ ERROR ]: O Arquivo de propriedades não existe no diretorio"
	echo "Favor verificar o arquivo em: ${PFHOME}/"
	echo -e "Nome do arquivo esperado é: ${PFFILE}\n"
	exit 1
else

	source ${PFHOME}/${PFFILE}
fi

# Ativa os modo de argumentos
# -f Encaminha toda a saida para o arquivo
# -x Realiza o output em formato debug
# -h Mostra uma ajuda

while [ $# -gt 0 ];do

        unset OPTIND
        unset OPTARG
        while getopts fxh options;do
                case ${options} in

                        f)
				if [ ! -d ${LOGDIR} ];then

					echo -e "[ ERROR ]: Diretorio de logs não está criado"
					echo "Procurando os logs em: ${LOGDIR}/"
					echo "Favor verificar o arquivo profile.properties"
					exit 1
				else
                                	exec >> ${LOGDIR}/${NOME}_${DATA}.log
				fi
                        ;;
                        x)
                                set -x
                        ;;
                        h)
				if [ ! -f ${SCRIPTDIR}/readme.txt ];then

                                        echo -e "[ ERROR ]: Arquivo de ajuda não localizado"
                                        echo "Procurando o arquivo em: ${SCRIPTDIR}/readme.txt"
                                        echo "Favor verificar o arquivo"
                                        exit 1
                                else
                                        clear
                                        cat ${SCRIPTDIR}/readme.txt
                                        exit 0
                                fi
                        ;;
                esac
        done
        shift $((OPTIND-1))
        ARGS="${ARGS} $1"
        shift
done

echo -e "\n[ INFO ]: Carregando as variaveis de ambiente:\n"
grep "export" ${PFHOME}/${PFFILE} | awk '{print $2}'
echo -e "\n"


# Verifica se o binário do azcopy existe no diretorio especificado
# Caso o arquivo não exista, encerra o script com a mensagem de erro

if [ ! -f ${BINDIR}/azcopy ];then

	echo -e "\n[ ERROR ]: O binario do azcopy não foi encontrado no diretorio"
	echo -e "Favor verificar o arquivo em: ${BINDIR}/\n"
	exit 1
fi

# Valida quantidade de parâmetros informados
# Caso a quantidade de parâmetros for maior que 0
# Será realizada uma cópia especifica por arquivos
# Neste caso poderá ser passado um ou mais arquivos
# Se não for passado argumentos o script ira procurar por todos os arquivos no diretorio
# E ira movimentar todos de uma única vez

# func_AZCOPY - Responsável pela cópia do arquivo para o Azure-Blob, bem como pela movimentação do mesmo para a pasta de backup
# A função recebe três parâmetros que são respectivamente: Nome do Arquivo, Diretorio de Movimentação e Diretorio do Azure
# ${BINDIR} - é o diretorio onde fica armazenado o binário do azcopy
# ${FILE} - é recebido da funcao func_VALIDAF e corresponde ao nome do arquivo a ser copiado
# ${DESTDIR} é recebido do arquivo de propriedades e corresponde ao caminho do Azure antes do diretorio do projeto
# ${AZDIR} - é recebido da funcao func_VALIDAF e corresponde ao nome do projeto em si, ex: Price
# ${AZTOKEN} - é recebido do arquivo de propriedades e corresponde a chave de autenticação no Azure
# ${FILEU} - é recebido da funcao func_VALIDAF e corresponde ao caminho completo do arquivo a ser movimentado
# ${ORDIR} -  é recebido do arquivo de propriedades e corresponde ao caminho de Origem dos arquivos
# ${MVDIR} - é recebido da funcao func_VALIDAF e corresponde ao caminho de destino do arquivo movimentado


func_AZCOPY(){

	FILE=$1
	MVDIR=$2
	AZDIR=$3

	echo "[ INFO ]: Iniciando a copia para o Azure"
	echo "Origem: ${FILE}"
	echo -e "Destino: ${DESTDIR}/${AZDIR}/ \n"
	${BINDIR}/azcopy copy "${FILE}" "${DESTDIR}/${AZDIR}/${AZTOKEN}"

	echo "[ INFO ]: Realizando a movimentação do arquivo pós copia"
	echo "Origem: ${FILE}"
	echo -e "Destino: ${ORDIR}/${MVDIR}/ \n"
	mv ${FILE} ${ORDIR}/${MVDIR}/
}

# func_EXPURGO - Realiza o compactamento das mensagens de acordo com a politica configurada no arquivo de propriedades
# Realiza também a exclusão dos mesmos seguindo as politicas no arquivo de propriedades
# ${ORDIR} é recebido do arquivo de propriedades e corresponde ao caminho de Origem dos arquivos
# ${MVPURGE} é recebido do arquivo de propriedades e corresponde ao numero de dias para compactar os arquivos
# ${EXPURGO} é recebido do arquivo de propriedades e corresponde ao numero de dias para excluir os arquivos

func_EXPURGO(){

	echo "[ INFO ]: Iniciando a função de expurgo dos arquivos"
	echo -e "\nIniciando rotina de compactacao para arquivos com mais de ${MVPURGE} dias"

	FINDEXZ='find '${ORDIR}'/ -type f -mtime '+${MVPURGE}' -name "*.csv"'
	CFIND=`${FINDEXZ}`

	if [ -n "${CFIND}" ];then

		echo "Arquivos que serão compactados:"
		echo `${FINDEXZ} | xargs`
		${FINDEXZ} | xargs gzip -9
	else
		echo "Não há arquivos no periodo de ${MVPURGE} dias"
		echo -e "Não é necessário compactar\n"
	fi

	FINDEXX='find '${ORDIR}'/ -type f -mtime +'${EXPURGO}' -name "*.gz"'
	CFIND=`${FINDEXX}`

	echo -e "\nIniciando rotina de exclusão para arquivos com mais de ${EXPURGO} dias"
	if [ -n "${CFIND}" ];then

		echo -e "Arquivos que serão removidos:"
		echo `${FINDEXX} | xargs`
		${FINDEXX} | xargs rm -f
	else
		echo "Não há arquivos no periodo de ${EXPURGO} dias"
		echo -e "Não é necessário remover\n"
	fi

	# Removendo os arquivos de logs 
	find ${SCRIPTDIR}/ -type f -mtime +${LPURGE} -name "*.log" -delete
}

# func_VALIDAF - Valida o nome do arquivo com o parâmetro base
# Verifica se o nome passado condiz com algum dos nomes de referência
# Se sim chama o azcopy e envia para o Azure
# Se não executa a mensagem de erro e não segue com a copia
# fileu - Recebe da funcao func_VDIRS - contém o nome do arquivo
# MVDIR - Recebe da funcao func_VDIRS - contém o nome do diretorio de backup
# AZDIR - Recebe da funcao func_VDIRS - contém o nome do projeto para montar o path no Azure
# files - Fatia o nome do arquivo removendo o caminho
# VFILES - Recebe os nomes de referência
# Essa função é responsável pela chamada da função func_AZCOPY

func_VALIDAF(){

	fileu=$1
	MVDIR=$2
	AZDIR=$3
	files=`echo "${fileu}" | awk -F "/" '{print $NF}'`

	# Inicia o código com a variavel SUCESS nula.
	# Se a variavel permanecer nula significa que ou os arquivos não foram corretamente identificados
	# Ou o nome dos mesmos está incorreto
	# Esta validação é feita arquivo por arquivo 
	# Utiliza=se os nomes de modelo para essa validação
	# Se o nome do arquivo estiver ok, Sucess recebe 1 e somente neste caso chama a função func_AZCOPY

	SUCESS=""
	echo "[ INFO ]: Verificando integridade do nome dos arquivos: "
	for vfiles in ${VFILES};do
		
		VINTEG=`echo "${files}" | grep -c ${vfiles}`

		if [ ${VINTEG} -ge 1 ];then
		
			echo "Arquivo: ${files} está de acordo com os parametros estabelecidos: ${vfiles}"
			echo -e "Variavel Sucess estabelecida\n"
			SUCESS=1
		fi
	done

	if [ -z "${SUCESS}" ];then
		
		echo -e "\n[ ERROR ]: Erro ao validar o arquivo ou nome do arquivo"
		echo -e "Favor verificar o arquivo: ${files}\n"
	else

		echo "[ INFO ]: Validação do nome do arquivo"
		echo "Validação realizada com sucesso"
		echo "Chamando a função func_AZCOPY"
		echo -e "Passando parametros para a funcao: ${fileu} ${MVDIR} ${AZDIR}\n"
		func_AZCOPY ${fileu} ${MVDIR} ${AZDIR}
	fi

}

# func_VDIRS - responsável por identificar o arquivo, identificar o projeto e construir as regras
# Nesta função serão criados os diretorios para os projetos, também será identificado o nome exato do arquivo
# Nesta função é gerado o nome do arquivo com base no nome parcial, ou o nome do arquivo completo com base no find
# O nome parcial é utilizado quando executado junto ao script, ou seja passado como parâmetro
# O nome que o find traz é utilizado quando não é passado parâmetro
# Essa função é responsável pela chamada da função func_VALIDAF

func_VDIRS(){


	# PARAM recebe 1 - quando for passados os parametros junto ao script
	# FILEU recebe os arquivos localizados no diretorio ${ORDIR} que correspondam ao nome passado como parametro
	# O find neste caso é case insensitive, só busca por arquivos e ignora tudo que estiver com nome movimentados
	# Com isso os arquivo movimentados após a copia não serão pegos pelo find.

	# PARAM recebe 0 - quando o script for chamado sem parametros
	# FILEU recebe a lista com todos os arquivos localizados no diretorio ${ORDIR}
	# O find respeita as mesmas condições descritas acima e incrementa um xargs para definir todos os arquivos inline
	# Este find está declarado na chamada da função no fim do script
	# files fatia somente o nome do arquivo para tratativa dos projetos
	
	if [ ${PARAM} -eq 1 ];then

		echo "[ INFO ]: Procurando arquivo passado como parâmetro"
		echo "Procurando arquivo ${files} em ${ORDIR}. Ignorando: ${IGNAME}"
		FILEU=(`find ${ORDIR} -iname "*${files}*" -type f -not -path "*${IGNAME}*"`)
		echo -e "Arquivo(s) localizado(s) ${FILEU}\n"

	elif [ ${PARAM} -eq 0 ];then 

		echo "[ INFO ]: Procurando arquivos para chamada sem parâmetros"
		FILEU=${files}
		files=`echo "${FILEU}" | awk -F "/" '{print $NF}'`
		echo -e "Arquivos localizados: ${FILEU}\n"

	fi

	# Verifica se os arquivos recebidos são recebidos um a um ou em lista dentro do array
	# Define a variavel de validação para tratativa posterior
	# No caso de multiplos a funcao func_AZCOPY será chamada dentro do for
	# E será invocada uma cópia para cada arquivo dentro do laço invocado
	# No caso de unico a funcao func_AZCOPY será invocada diretamente

	echo "[ INFO ]: Identificando se entrada é multipla ou unica"
	if [ `echo ${#FILEU[@]}` -gt 1 ];then

		echo -e "Entrada identificada: multiplo\n"
		TFILES="multiplo"

	else
		
		echo -e "Entrada identificada: unico\n"
		TFILES="unico"
	fi

	# Cria uma validação de projeto
	# Neste caso com base no nome do arquivo define o projeto que ele pertence
	# Serão então criados os nomes para diretorio de movimentação e composição do PATH no AZURE
	
	if [ `echo ${files} | grep -ic "price"` -gt 0 ];then

		MVDIR="${MVPRICE}"
		AZDIR="${AZPRICE}"

	elif [ `echo ${files} | grep -ic "product"` -gt 0 ];then

		MVDIR="${MVPRODUCT}"
		AZDIR="${AZPRODUCT}"

	elif [ `echo ${files} | grep -ic "stock"` -gt 0 ];then

		MVDIR="${MVSTOCK}"
		AZDIR="${AZSTOCK}"

	elif [ `echo ${files} | grep -ic "warehouse"` -gt 0 ];then

		MVDIR="${MVWAREHOUSE}"
		AZDIR="${AZWAREHOUSE}"
	fi
		
	echo "[ INFO ]: Projeto identificado:"
	echo "Projeto: ${AZDIR}"
	echo -e "Diretorio para movimentação: ${MVDIR}\n"

	# Se o diretorio de movimentação não existir cria ele

	if [ ! -d ${ORDIR}/${MVDIR}/ ];then

		echo "[ WARNING ]: Diretório não encontrado."
		echo -e "Diretorio inexistente: ${ORDIR}/${MVDIR}/\n"
		echo "[ INFO ]: Criando o diretorio"
		echo -e "Diretório: ${ORDIR}/${MVDIR}/\n"
		mkdir -p ${ORDIR}/${MVDIR}/

	fi

	if [ "${TFILES}" == "multiplo" ];then

		if [ -n "${FILEU[0]}" ];then

			for fileu in ${FILEU[@]};do

				func_VALIDAF ${fileu} ${MVDIR} ${AZDIR}
			done
		else
			echo -e "\n[ INFO ]: Não há arquivos a serem copiados"
		fi

	elif [ "${TFILES}" == "unico" ];then

		if [ -n "${FILEU}" ];then

			func_VALIDAF ${FILEU} ${MVDIR} ${AZDIR}
		else
			echo -e "\n[ INFO ]: Não há arquivos a serem copiados"

		fi

	else

		echo "[ WARNING ]: Não há arquivos a serem copiados"

	fi

}

# Inicio da execução do código propriamente dita
# As funções declaradas acima passam a ser consumidas deste ponto

ARG=`echo ${ARGS} | sed 's/^ //' | sed 's/$ //'`
if [ -n "${ARG}" ];then

	PARAM=1
	for files in ${ARG};do

		echo -e "\nIniciando processo de copias, PROJETO: ${files}\n"
		func_VDIRS

	done
else
	PARAM=0
	FILES=`find ${ORDIR} -type f -not -path "*${IGNAME}*" | xargs`

	for files in ${FILES};do
	
		func_VDIRS
	done
	
fi

func_EXPURGO
