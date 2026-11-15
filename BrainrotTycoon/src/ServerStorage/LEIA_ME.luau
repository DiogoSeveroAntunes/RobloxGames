--[[
BRAINROT TYCOON — LEIA-ME (v2, 10 rebirths)
===========================================
ESTRUTURA
- 10 andares por base (140x140). Andares 1-3 livres; 4=R1, 5=R2, 6=R3, 7=R5, 8=R7, 9=R9, 10 (Trono Supremo)=R10.
- Cada andar: 2 esteiras, 4 droppers + 2 upgraders por esteira, paredes, 3 móveis, 6 brainrots (buff % nos droppers), escada.
- Buff total dos 60 brainrots = 150% (só alcançável no Rebirth 10). Andares 1-3 têm 3 brainrots extras liberados no R1.
- Rebirth: +50% de renda por rebirth, máximo 10. Custos em Config.Rebirth.Costs.
- Níveis de dropper: aperte F perto de um dropper (custo x3 por nível, +50% de valor). Nível máx = 3 + floor(rebirths/2).
- 11 armas e 12 skins na Loja, com rebirth mínimo.

ROBUX (configure antes de publicar!)
1) Creator Dashboard > sua experiência > Monetização:
   - Game Passes: crie "2x Dinheiro", "Auto Coletar", "Offline VIP", "Corrida Rápida".
     Cole os IDs em Config.GamePasses[...].PassId.
   - Developer Products: crie 20 produtos (VipDropper1..10 e VipUpgrader1..10).
     Cole os IDs em Config.VipProductIds (mesmos nomes de chave).
2) Com ID = 0 a compra é SIMULADA (só funciona no Studio, para testes).
3) Ative "Allow HTTP/API Services" e publique o jogo para o DataStore funcionar.

DATASTORE: "BrainrotTycoon_v2". Saves antigos são reconciliados (rebirths limitados a 10).
DEBUG (só Studio): RemoteEvent DebugTycoon com "cash", "bank", "rebirths".

]]