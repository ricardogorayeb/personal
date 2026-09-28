import ipaddress

# Lista com os arquivos de origem disponíveis no diretório
arquivos = [
    "/tmp/blocked-ips.txt",
    "/tmp/blocked-ips2.txt",
    "/tmp/blocked-ips3.txt",
    "/tmp/blocked-ips4.txt"
]

def processar_arquivos_txt(lista_arquivos):
    tamanhos_originais = []
    todos_ips = []

    for arquivo in lista_arquivos:
        try:
            with open(arquivo, "r", encoding="utf-8") as f:
                conteudo = f.read()
                # Separa os IPs por vírgula e remove espaços extras
                ips = [ip.strip() for ip in conteudo.split(",") if ip.strip()]
                tamanhos_originais.append(len(ips))
                todos_ips.extend(ips)
        except FileNotFoundError:
            print(f"Aviso: O arquivo '{arquivo}' não foi encontrado.")

    # Define o tamanho máximo de cada lista com base na maior lista original
    tamanho_alvo = max(tamanhos_originais) if tamanhos_originais else 0
    
    ips_vistos = set()
    faixas_vistas = set()
    ips_unicos = []

    for ip_str in todos_ips:
        try:
            ip_obj = ipaddress.ip_address(ip_str)
            
            if isinstance(ip_obj, ipaddress.IPv4Address):
                # Extrai a faixa /24 (primeiros 3 octetos)
                partes = ip_str.split('.')
                faixa_24 = f"{partes[0]}.{partes[1]}.{partes[2]}"
                
                if ip_str not in ips_vistos and faixa_24 not in faixas_vistas:
                    ips_vistos.add(ip_str)
                    faixas_vistas.add(faixa_24)
                    ips_unicos.append(ip_str)
            else:
                if ip_str not in ips_vistos:
                    ips_vistos.add(ip_str)
                    ips_unicos.append(ip_str)
        except ValueError:
            continue

    # Redistribui os IPs limpos em novas listas respeitando o limite por arquivo
    novas_listas = []
    for i in range(0, len(ips_unicos), tamanho_alvo):
        novas_listas.append(ips_unicos[i:i + tamanho_alvo])

    return novas_listas

# Executa o processamento e grava os novos arquivos
resultado = processar_arquivos_txt(arquivos)
for idx, nova_lista in enumerate(resultado, 1):
    nome_arquivo = f"blocked-ips-unificados-{idx}.txt"
    with open(nome_arquivo, "w", encoding="utf-8") as f:
        f.write(", ".join(nova_lista))
    print(f"Lista {idx} gerada com {len(nova_lista)} objetos salva em '{nome_arquivo}'.")