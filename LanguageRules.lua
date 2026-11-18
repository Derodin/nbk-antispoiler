local _, addon = ...
local profile = addon.GtaVI
if not profile then return end

-- All detection packs run together, independently of the client's UI locale.
local languages = {
    enUS = {
        references = {},
        verbs = { died = "die", killed = "kill" },
        corrections = { never = true },
        rules = {
            { "event", "death", "died", "is killed", "was killed", "gets murdered" },
            { "hint", "ending", "in the end", "last mission", "final mission" },
            { "maybe", "hypothesis", "might", "could", "would" },
        },
    },
    frFR = {
        references = { elle = "female", il = "male", elles = "plural", ils = "plural" },
        verbs = { va = "go", vont = "go", meurt = "die", meurent = "die", trompe = "cheating",
            quitte = "breakup", quittent = "breakup", rompt = "breakup", rompent = "breakup" },
        corrections = { non = true, ne = true, pas = true, jamais = true },
        rules = {
            { "hint", "mission", "mission", "missions" },
            { "hint", "chapter", "chapitre", "chapitres" },
            { "hint", "ending", "à la fin", "a la fin", "dernière mission", "derniere mission", "fin du jeu" },
            { "hint", "vehicle", "voiture", "voitures", "véhicule", "véhicules", "vehicule", "vehicules", "moto", "motos" },
            { "hint", "firearm", "pistolet", "pistolets", "flingue", "flingues", "fusil", "fusils" },
            { "hint", "pursuit", "course poursuite", "poursuite policière", "poursuite policiere", "indice de recherche" },
            { "hint", "heist", "braquage", "braquages", "cambriolage" },
            { "event", "death", "meurt", "meurent", "est morte", "est mort", "se fait tuer", "a été tuée", "a été tué",
                "a ete tuee", "a ete tue", "casse sa pipe", "passe l'arme à gauche", "passe l'arme a gauche" },
            { "action", "death", "mourir", "tuer" },
            { "event", "breakup", "se sépare", "se séparent", "se separe", "se separent", "rompt", "rompent", "se quittent" },
            { "action", "breakup", "séparation", "separation", "rupture" },
            { "event", "cheating", "trompe" },
            { "action", "cheating", "infidélité", "infidelite" },
            { "wow", "raid", "donjon", "donjons", "en raid", "dans le raid" },
            { "maybe", "hypothesis", "si", "peut-être", "peut etre", "supposons", "hypothétiquement", "hypothetiquement" },
        },
    },
    esES = {
        references = { ella = "female", ["él"] = "male", ellas = "plural", ellos = "plural" },
        verbs = { va = "go", van = "go", muere = "die", mueren = "die", ["murió"] = "die", murio = "die", ["engaña"] = "cheating",
            rompe = "breakup", rompen = "breakup", separa = "breakup", separan = "breakup" },
        corrections = { nunca = true, mentira = true },
        rules = {
            { "figure", "lucia", "lucía" },
            { "hint", "mission", "misión", "mision", "misiones" },
            { "hint", "chapter", "capítulo", "capitulo", "capítulos", "capitulos" },
            { "hint", "ending", "al final", "última misión", "ultima mision", "final del juego" },
            { "hint", "vehicle", "coche", "coches", "carro", "carros", "vehículo", "vehículos", "vehiculo", "vehiculos", "moto", "motos" },
            { "hint", "firearm", "pistola", "pistolas", "arma de fuego", "armas de fuego", "escopeta", "escopetas" },
            { "hint", "pursuit", "persecución policial", "persecucion policial", "nivel de búsqueda", "nivel de busqueda" },
            { "hint", "heist", "atraco", "atracos", "asalto", "asaltos", "robo de banco" },
            { "event", "death", "muere", "mueren", "murió", "murio", "está muerta", "esta muerta", "está muerto", "esta muerto",
                "la matan", "lo matan", "estira la pata" },
            { "action", "death", "morir", "matar" },
            { "event", "breakup", "se separa", "se separan", "rompe con", "rompen", "termina con" },
            { "action", "breakup", "separación", "separacion", "ruptura" },
            { "event", "cheating", "engaña a", "engana a",
                "le pone los cuernos", "pone los cuernos" },
            { "action", "cheating", "infidelidad" },
            { "wow", "raid", "mazmorra", "mazmorras", "en la banda", "en banda" },
            { "maybe", "hypothesis", "si", "quizás", "quizas", "tal vez", "supongamos", "hipotéticamente", "hipoteticamente" },
        },
    },
}

for _, language in pairs(languages) do
    for word, reference in pairs(language.references) do profile.references[word] = reference end
    for word, verb in pairs(language.verbs) do profile.verbs[word] = verb end
    for word, correction in pairs(language.corrections) do profile.corrections[word] = correction end
    for _, rule in ipairs(language.rules) do profile.rules[#profile.rules + 1] = rule end
end
