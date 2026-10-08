import os
import re
import random

ip_map = {}
# Regex agressiva: captura blocos de IP isolando-os de portas, URLs ou textos grudados
ip_pattern = re.compile(r'\b(?<!\.)(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?!\.)\b')

# Extensões conhecidas de arquivos binários ou compactados que NÃO devemos abrir para não corromper
EXTENSOES_IGNORADAS = ('.zip', '.tar.gz', '.tgz', '.gz', '.png', '.jpg', '.jpeg', '.gif', '.pdf', '.iso')

def gerar_ip_ficticio(ip_original):
    if ip_original in ['127.0.0.1', '0.0.0.0', '255.255.255.255']:
        return ip_original
        
    if ip_original in ip_map:
        return ip_map[ip_original]
    
    blocos = ip_original.split('.')
    if any(int(b) > 255 for b in blocos):
        return ip_original

    primeiro_bloco = blocos[0]
    if primeiro_bloco in ['10', '172', '192']:
        if primeiro_bloco == '10':
            novo_ip = f"10.{random.randint(10,99)}.{random.randint(10,99)}.{random.randint(10,99)}"
        elif primeiro_bloco == '192':
            novo_ip = f"192.168.{random.randint(10,99)}.{random.randint(10,99)}"
        else:
            novo_ip = f"172.{random.randint(16,31)}.{random.randint(10,99)}.{random.randint(10,99)}"
    else:
        novo_ip = f"203.0.113.{random.randint(1, 254)}"
        
    ip_map[ip_original] = novo_ip
    return novo_ip

def processar_arquivo(caminho_arquivo):
    try:
        # Abre o arquivo ignorando erros de caracteres estranhos (útil para scripts e confs)
        with open(caminho_arquivo, 'r', encoding='utf-8', errors='ignore') as f:
            conteudo = f.read()
        
        # Executa a substituição dos IPs
        novo_conteudo = ip_pattern.sub(lambda m: gerar_ip_ficticio(m.group(0)), conteudo)
        
        with open(caminho_arquivo, 'w', encoding='utf-8') as f:
            f.write(novo_conteudo)
        return True
    except Exception as e:
        print(f"  [ERRO] Não foi possível processar {caminho_arquivo}: {e}")
        return False

def executar():
    print("🚀 Iniciando varredura TOTAL em todos os arquivos de texto...")
    contador = 0
    
    for raiz, _, arquivos in os.walk('.'):
        # Ignora a pasta interna do Git
        if '.git' in raiz:
            continue
            
        for arquivo in arquivos:
            if arquivo == 'anonimizar_total.py':
                continue
                
            caminho_completo = os.path.join(raiz, arquivo)
            
            # Pula arquivos compactados/binários listados na constante lá em cima
            if arquivo.lower().endswith(EXTENSOES_IGNORADAS):
                print(f"  [IGNORADO - BINÁRIO] {caminho_completo}")
                continue
                
            if processar_arquivo(caminho_completo):
                contador += 1
                print(f"  [OK] Processado: {caminho_completo}")
                
    print(f"\n✅ Concluído! {contador} arquivos analisados/alterados.")
    print("📊 Tabela final de mascaramento de IPs:")
    for real, ficticio in ip_map.items():
        print(f"  {real} ➡️ {ficticio}")

if __name__ == "__main__":
    executar()

