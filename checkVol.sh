#!/bin/bash
exec >> /home/muran/Scripts_FTP_Radar/saida_script.log 2>&1

BASENAME=$(which basename)
RSYNC=$(which rsync)
BZIP2=$(which bzip2)
ZABBIXSENDER=$(which zabbix_sender)
NOME_MAQUINA=$(hostname)
LOCAL_RADAR=${NOME_MAQUINA: -4}

DIRVMET="/home/muran/data/rdc-$LOCAL_RADAR/scan_vmet/"
DIRXPPI="/home/muran/data/rdc-$LOCAL_RADAR/scan_xppi/"

DIRBASEVMET="/home/muran/MVOL.sinc/scan_vmet"
DIRBASEXPPI="/home/muran/MVOL.sinc/scan_xppi"

DIRRSYNCVMET="rsync://root@radproc:/Volumes${LOCAL_RADAR^^}_VMET"
DIRRSYNCXPPI="rsync://root@radproc:/Volumes${LOCAL_RADAR^^}_XPPI"

DIRVMET_VALIDOS="$DIRVMET/0movidos"
DIRVMET_INVALIDOS="$DIRVMET/0invalidos"

DIRXPPI_VALIDOS="$DIRXPPI/0movidos"
DIRXPPI_INVALIDOS="$DIRXPPI/0invalidos"

dirs=("$DIRBASEVMET" "$DIRBASEXPPI" "$DIRVMET_VALIDOS" "$DIRVMET_INVALIDOS" "$DIRXPPI_VALIDOS" "$DIRXPPI_INVALIDOS")

for dir in "${dirs[@]}"; do
    if [ ! -d "$dir" ]; then
    	mkdir -p "$dir"
    fi
done

while true; do
	INVALIDO=0

	# SCAN VMET
	echo "CHECANDO SCAN VMET"
	for ARQFULL in $(ls $DIRVMET/*.mvol 2>/dev/null | tail -n850); do
		ARQ=$($BASENAME "$ARQFULL")
		
		# Trava 1: Ignora leitura se o descritor estiver alocado
		if fuser -s "$ARQFULL"; then
			continue
		fi
		
		NUMVOL=$(strings "$ARQFULL" | grep scan[0-9] | wc -l)
		echo "QTD ARQS: $NUMVOL"
		
		if [ "$NUMVOL" -eq 17 ]; then
			INVALIDO=0
			NOMEVOL=$($BASENAME "$ARQ" | sed -r 's/(.*)\--(.{2})\:(.{2})\:(.*\..*)/\1\_\2\3/')
			ANO=$(echo "${NOMEVOL}" | cut -c1-4)
			MES=$(echo "${NOMEVOL}" | cut -c6-7)
			DIA=$(echo "${NOMEVOL}" | cut -c9-10)
			
			if [ -s "$DIRBASEVMET/$ANO/$MES/$DIA/${NOMEVOL}.mvol.bz2" ]; then
				echo "ARQUIVO EXISTE $NOMEVOL"
			else	
				echo "ORGANIZANDO.. ARQUIVO VMET $ARQ"
				mkdir -p "$DIRBASEVMET/$ANO/$MES/$DIA"
				
				echo "COPIANDO ARQUIVO $ARQ"
				cp -rp "$ARQFULL" "$DIRBASEVMET/$ANO/$MES/$DIA/${NOMEVOL}.mvol"
				mv "$ARQFULL" "$DIRVMET_VALIDOS/$ARQ"
				$BZIP2 -f "$DIRBASEVMET/$ANO/$MES/$DIA/${NOMEVOL}.mvol"
			fi
		else
			# Condição de descarte temporal: Mais de 3600s sem gravação e incompleto
			HORA_ATUAL=$(date +%s)
			HORA_MOD_ARQ=$(stat -c %Y "$ARQFULL")
			DIFERENCA=$((HORA_ATUAL - HORA_MOD_ARQ))

			if [ "$DIFERENCA" -gt 3600 ]; then
				echo "$ARQ"
				echo "Movendo arquivo VMET invalido (inativo há ${DIFERENCA}s) ... ${NUMVOL}"
				INVALIDO=1
				mv "$ARQFULL" "$DIRVMET_INVALIDOS/$ARQ"
			fi
		fi
	done
	
	# Verifica se há arquivos regulares aguardando no diretório base
	QTD_ARQS_VMET=$(find $DIRBASEVMET/ -type f | wc -l)

	if [ "$QTD_ARQS_VMET" -gt 0 ]; then
    	$RSYNC -avzr --timeout=60 --contimeout=30 --no-t --remove-source-files --exclude-from=/home/muran/exclude.txt --files-from=<(ls $DIRBASEVMET/ 2>/dev/null | tail -n850) $DIRBASEVMET/ $DIRRSYNCVMET 
	fi
	
	# SCAN XPPI
	echo "CHECANDO SCAN XPPI"
	for ARQFULL in $(ls $DIRXPPI/*.mvol 2>/dev/null | tail -n350); do
		ARQ=$($BASENAME "$ARQFULL")
		
		# Trava 1: Ignora leitura se o descritor estiver alocado
		if fuser -s "$ARQFULL"; then
			continue
		fi

		NUMVOL=$(strings "$ARQFULL" | grep scan[0-9] | wc -l)
		echo "$NUMVOL"

		if [ "$NUMVOL" -eq 3 ]; then
			NOMEVOL=$($BASENAME "$ARQ" | sed -r 's/(.*)\--(.{2})\:(.{2})\:(.*\..*)/\1\_\2\3/')
			ANO=$(echo "${NOMEVOL}" | cut -c1-4)
			MES=$(echo "${NOMEVOL}" | cut -c6-7)
			DIA=$(echo "${NOMEVOL}" | cut -c9-10)

			if [ -s "$DIRBASEXPPI/$ANO/$MES/$DIA/${NOMEVOL}_400.mvol.bz2" ]; then
				echo "ARQUIVO EXISTE $NOMEVOL"
				mv "$ARQFULL" "$DIRXPPI_VALIDOS/$ARQ"
			else
				echo "ORGANIZANDO.. ARQUIVO XPPI $ARQ"
				mkdir -p "$DIRBASEXPPI/$ANO/$MES/$DIA"
				
				echo "COPIANDO ARQUIVO $ARQ"
				cp -rp "$ARQFULL" "$DIRBASEXPPI/$ANO/$MES/$DIA/${NOMEVOL}_400.mvol"
				mv "$ARQFULL" "$DIRXPPI_VALIDOS/$ARQ"
				$BZIP2 -f "$DIRBASEXPPI/$ANO/$MES/$DIA/${NOMEVOL}_400.mvol"
			fi
		else
			# Condição de descarte temporal: Mais de 3600s sem gravação e incompleto
			HORA_ATUAL=$(date +%s)
			HORA_MOD_ARQ=$(stat -c %Y "$ARQFULL")
			DIFERENCA=$((HORA_ATUAL - HORA_MOD_ARQ))

			if [ "$DIFERENCA" -gt 3600 ]; then
				echo "movendo arquivo XPPI invalido (inativo há ${DIFERENCA}s) ... ${NUMVOL}"
				mv "$ARQFULL" "$DIRXPPI_INVALIDOS/$ARQ"
			fi
		fi
	done

		QTD_ARQS_XPPI=$(find $DIRBASEXPPI/ -type f | wc -l)

	if [ "$QTD_ARQS_XPPI" -gt 0 ]; then
    	$RSYNC -avzr --timeout=60 --contimeout=30 --no-t --remove-source-files --exclude-from=/home/muran/exclude.txt --files-from=<(ls $DIRBASEXPPI/ 2>/dev/null | tail -n850) $DIRBASEXPPI/ $DIRRSYNCXPPI 
	fi

	echo "invalido={$INVALIDO}"

	sleep 60 
done
