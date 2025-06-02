# Minecraft Server Security Guide

## Resumo das Medidas de Segurança

Este guia fornece uma visão geral das medidas de segurança implementadas no servidor Minecraft para prevenir ataques e proteger os dados do servidor.

## 1. Controle de Acesso

### Whitelist
- **Sempre mantenha a whitelist ativa**: Adicione apenas jogadores conhecidos e confiáveis.
- **Enforce Whitelist**: Garante que mesmo após uma reinicialização a whitelist seja aplicada.
- **Comando de Verificação**: Use `/whitelist on` e `/whitelist reload` regularmente.

### Autenticação (EasyAuth)
- **Login obrigatório**: Impede que jogadores façam ações antes de autenticar.
- **Limites de tentativas**: Configure para banir temporariamente após falhas repetidas.
- **Tempo de sessão**: Defina um tempo razoável (30-60 minutos) para expiração da sessão.

### Gerenciamento de Operadores
- **Use o nível mínimo necessário**: Nível 4 apenas para administradores principais.
- **Revise regularmente**: Verifique periodicamente o arquivo `ops.json`.
- **Nunca dê OP no jogo**: Sempre edite o arquivo manualmente e reinicie o servidor.
- **Backups do ops.json**: Mantenha cópias seguras deste arquivo.

## 2. Proteção Anti-Griefing

### Plugins Recomendados
- **CoreProtect**: Registra todas as interações para rastreamento e rollback.
- **WorldGuard**: Define regiões onde apenas jogadores específicos podem construir.
- **GriefPrevention**: Sistema de claims para jogadores protegerem suas construções.
- **LockSecurity**: Protege baús, portas e outros blocos interativos.

### Configurações do Servidor
- **Proteção do spawn**: Defina um raio adequado (16-32 blocos).
- **Bloqueie comandos prejudiciais**: Desative `/op`, `/deop`, `/gamemode` etc. para não-operadores.
- **Limites de mundo**: Configure limites de mundo adequados para evitar exploração excessiva.

## 3. Backups e Recuperação

### Estratégia de Backup
- **Frequência**: Backups automáticos a cada 6-12 horas.
- **Retenção**: Mantenha backups por pelo menos 30 dias.
- **Offsite Storage**: Copie regularmente backups para armazenamento externo.
- **Verificação de integridade**: Teste regularmente a restauração de backups.

### Procedimento de Recuperação
1. **Identificar o ataque**: Verifique logs para entender o que aconteceu.
2. **Desligar o servidor**: Evite mais danos.
3. **Restaurar backup**: Use o backup mais recente antes do ataque.
4. **Corrigir vulnerabilidades**: Identifique como o ataque ocorreu e corrija.
5. **Atualizar senhas/permissões**: Redefina credenciais e permissões.

## 4. Monitoramento e Logs

### Logs Críticos para Monitorar
- **Logins**: Tentativas de login, especialmente falhas repetidas.
- **Comandos de Operador**: Todos os comandos `/op`, `/gamemode`, etc.
- **Alterações de Blocos**: Rastrear alterações em áreas sensíveis.
- **Conexões de IP**: Monitore IPs suspeitos ou múltiplas contas do mesmo IP.

### Ferramentas de Análise
- **CoreProtect**: Use `/co i` para inspecionar alterações de blocos.
- **Console Logs**: Revise regularmente `/data/logs/latest.log`.
- **Scripts de Monitoramento**: Use os scripts fornecidos para analisar padrões suspeitos.

## 5. Lista de Verificação de Segurança Semanal

- [ ] Verificar arquivo `ops.json` por operadores não autorizados
- [ ] Revisar whitelist e remover jogadores inativos/desconhecidos
- [ ] Verificar logs por atividades suspeitas
- [ ] Testar restauração de backup em ambiente de teste
- [ ] Atualizar plugins e servidor para corrigir vulnerabilidades
- [ ] Verificar configurações de EasyAuth e outros plugins de segurança
- [ ] Revisar proteções de áreas principais (spawn, bases importantes)
- [ ] Testar que comandos restritos não podem ser executados por jogadores regulares

## 6. Em Caso de Ataque

1. **Desconecte o servidor** da rede imediatamente
2. **Documente tudo**: Capture logs, estado do servidor e danos
3. **Identifique o vetor de ataque**: Como o invasor ganhou acesso
4. **Restaure de backup seguro**: Use um backup anterior ao comprometimento
5. **Corrija vulnerabilidades**: Resolva os problemas que permitiram o ataque
6. **Altere todas as senhas**: RCON, painéis de administração, etc.
7. **Atualize a whitelist**: Remova contas suspeitas
8. **Reinicie com configurações seguras**: Aplique todas as recomendações deste guia
