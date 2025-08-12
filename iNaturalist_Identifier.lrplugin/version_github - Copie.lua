-- Fonction pour exécuter une commande shell et récupérer la sortie
local function exec(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

-- URL de l'API GitHub
local url = "https://api.github.com/repos/pbranly/Inaturalist-Identifier-Lightroom/releases/latest"

-- Exécution de curl
local response = exec("curl -s " .. url)

-- Extraction du champ "tag_name" avec une expression régulière
local tag = response:match('"tag_name"%s*:%s*"([^"]+)"')

-- Affichage du résultat
if tag then
    print("Dernier tag publié : " .. tag)
else
    print("Impossible de trouver le champ tag_name.")
end