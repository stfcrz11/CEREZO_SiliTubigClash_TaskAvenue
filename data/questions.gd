extends RefCounted
## Question bank: Filipino culture (mythology, epics, traditions, games,
## food and places). Each entry: q = question, choices = 4 options,
## answer = index of the correct option in choices, fact = short note shown
## after answering. Add or edit entries freely; the game draws them at random.
##
## Which list is used where (scenes/maze_game.gd):
##   QUESTIONS - "?" scrolls, Buhos-Tubig rescues, Halo-Halo coolers,
##               Kalamansi gates
##   HARD      - "Huling Hirit" self-thaw (2 in a row)
##   BUGTONG   - Bicol Express pepper checkpoints (Sili only)

const QUESTIONS := [
	{"q": "In Philippine mythology, which creature separates its upper body and flies at night?", "choices": ["Manananggal", "Tikbalang", "Kapre", "Tiyanak"], "answer": 0, "fact": "The manananggal leaves its lower body behind before flying."},
	{"q": "Which creature is part human and part horse, and makes travelers lose their way?", "choices": ["Kapre", "Tikbalang", "Duwende", "Sirena"], "answer": 1, "fact": "Wearing your shirt inside-out is said to break the tikbalang's trick."},
	{"q": "Which giant is said to live in big trees like the balete and smoke a huge cigar?", "choices": ["Aswang", "Nuno sa Punso", "Kapre", "Bakunawa"], "answer": 2, "fact": "The kapre is often described sitting in balete or acacia trees."},
	{"q": "Who is the supreme god and creator in Tagalog mythology?", "choices": ["Apolaki", "Mayari", "Bathala", "Tala"], "answer": 2, "fact": "Bathala was the highest deity of the ancient Tagalogs."},
	{"q": "Which sea serpent in Philippine myth tries to swallow the moon, causing eclipses?", "choices": ["Bakunawa", "Minokawa", "Sarimanok", "Tambanokano"], "answer": 0, "fact": "People banged pots and pans to scare the Bakunawa into releasing the moon."},
	{"q": "In Tagalog mythology, Mayari is the goddess of the...", "choices": ["Sea", "Moon", "Harvest", "Wind"], "answer": 1, "fact": "Mayari is a daughter of Bathala and rules the moon."},
	{"q": "Apolaki is the Tagalog god of the sun and of...", "choices": ["War", "Rain", "Love", "Rice"], "answer": 0, "fact": "Apolaki is the sun god and a patron of warriors."},
	{"q": "Where does the Nuno sa Punso live?", "choices": ["In a river", "In an anthill or mound", "In a coconut tree", "In the clouds"], "answer": 1, "fact": "People say 'Tabi-tabi po' to avoid disturbing the nuno."},
	{"q": "The Tiyanak usually appears as a...", "choices": ["Black dog", "Crying baby", "Old woman", "White horse"], "answer": 1, "fact": "It lures travelers by crying like a lost infant."},
	{"q": "'Aswang' is a general Filipino term for a...", "choices": ["Friendly fairy", "Shape-shifting evil creature", "Sea goddess", "Rice spirit"], "answer": 1, "fact": "Aswang stories are especially known in the Visayas."},
	{"q": "Maria Makiling is the guardian spirit of which mountain?", "choices": ["Mt. Apo", "Mt. Arayat", "Mt. Makiling", "Mt. Pulag"], "answer": 2, "fact": "Mt. Makiling is in Laguna."},
	{"q": "Mariang Sinukuan is the guardian spirit of which mountain?", "choices": ["Mt. Arayat", "Mt. Banahaw", "Mt. Mayon", "Mt. Makiling"], "answer": 0, "fact": "Mt. Arayat is in Pampanga."},
	{"q": "According to legend, which fruit came from a girl named Pinang who was told to grow 'many eyes'?", "choices": ["Mango", "Pineapple", "Banana", "Guava"], "answer": 1, "fact": "Pinya comes from the name Pinang."},
	{"q": "'Biag ni Lam-ang' is the epic of which people?", "choices": ["Ilocano", "Maranao", "Ifugao", "Kapampangan"], "answer": 0, "fact": "Lam-ang could already talk when he was born."},
	{"q": "The 'Darangen' epic, recognized by UNESCO, comes from the...", "choices": ["Ifugao", "Maranao", "Tagalog", "Waray"], "answer": 1, "fact": "The Darangen is chanted by the Maranao of Lanao."},
	{"q": "The 'Hudhud' chants, recognized by UNESCO, belong to the...", "choices": ["Ifugao", "Ilocano", "Bicolano", "Tausug"], "answer": 0, "fact": "Hudhud is chanted during rice harvesting and funerals."},
	{"q": "The epic 'Hinilawod' comes from which island?", "choices": ["Luzon", "Mindanao", "Panay", "Palawan"], "answer": 2, "fact": "It is one of the longest epics from the Visayas."},
	{"q": "What is the ancient Filipino writing system called?", "choices": ["Baybayin", "Kawi", "Sanskrit", "Jawi"], "answer": 0, "fact": "Each baybayin character stands for a syllable."},
	{"q": "What is the wide-brimmed traditional Filipino hat made of bamboo or rattan?", "choices": ["Bayong", "Salakot", "Banig", "Tapis"], "answer": 1, "fact": "The salakot protects farmers from sun and rain."},
	{"q": "What is the formal national attire for Filipino men?", "choices": ["Baro't saya", "Barong Tagalog", "Kimona", "Malong"], "answer": 1, "fact": "Barong is often woven from piña or jusi fabric."},
	{"q": "Which traditional board game uses shells or stones on a wooden board with holes?", "choices": ["Sungka", "Sipa", "Patintero", "Piko"], "answer": 0, "fact": "Sungka boards usually have 14 small holes and 2 big ones."},
	{"q": "Which Filipino folk dance has dancers stepping between clapping bamboo poles?", "choices": ["Pandanggo sa Ilaw", "Tinikling", "Cariñosa", "Maglalatik"], "answer": 1, "fact": "Tinikling imitates the tikling bird dodging traps."},
	{"q": "The Maranao royal dance performed with fans between bamboo poles is called...", "choices": ["Singkil", "Itik-itik", "Subli", "Kuratsa"], "answer": 0, "fact": "Singkil tells the story of a princess in the Darangen epic."},
	{"q": "'Bayanihan' best means...", "choices": ["A harvest song", "Community helping one another", "A kind of boat", "A rice cake"], "answer": 1, "fact": "It is often pictured as neighbors carrying a whole house."},
	{"q": "What is the star-shaped Filipino Christmas lantern called?", "choices": ["Parol", "Sarimanok", "Banig", "Palayok"], "answer": 0, "fact": "San Fernando, Pampanga is famous for its giant parols."},
	{"q": "What is the Filipino gesture of respect where you press an elder's hand to your forehead?", "choices": ["Bayanihan", "Pagmamano", "Harana", "Pamamanhikan"], "answer": 1, "fact": "It is usually done with 'Mano po'."},
	{"q": "What is the national flower of the Philippines?", "choices": ["Gumamela", "Ilang-ilang", "Sampaguita", "Waling-waling"], "answer": 2, "fact": "Sampaguita became the national flower in 1934."},
	{"q": "Which Filipino martial art, using sticks, is the national martial art and sport?", "choices": ["Sipa", "Arnis", "Buno", "Sikaran"], "answer": 1, "fact": "Arnis was declared the national martial art and sport in 2009."},
	{"q": "In which street game do players try to cross lines guarded by taggers?", "choices": ["Patintero", "Sungka", "Luksong Baka", "Sipa"], "answer": 0, "fact": "Patintero is played on a grid drawn on the ground."},
	{"q": "The Sarimanok, a colorful legendary bird, is a symbol of which people?", "choices": ["Maranao", "Ivatan", "Ilocano", "Tagalog"], "answer": 0, "fact": "It often holds a fish in its beak or claws."},
	{"q": "In Philippine folklore, a 'duwende' is a...", "choices": ["Dwarf or goblin spirit", "Sea monster", "Giant bird", "Horse spirit"], "answer": 0, "fact": "Duwende can be white (friendly) or black (mischievous)."},
	{"q": "Who wrote the novel 'Noli Me Tángere'?", "choices": ["Andres Bonifacio", "Jose Rizal", "Apolinario Mabini", "Emilio Jacinto"], "answer": 1, "fact": "It was published in Berlin in 1887."},
	# --- Pinoy food, refreshments and places ---
	{"q": "Which Philippine region is famous for spicy coconut-milk dishes like Bicol Express and Laing?", "choices": ["Ilocos Region", "Bicol Region", "Central Visayas", "Davao Region"], "answer": 1, "fact": "Bicolanos love sili and gata (coconut milk)."},
	{"q": "What is the small, fiery native chili pepper commonly found in the Philippines called?", "choices": ["Siling Haba", "Siling Labuyo", "Paminta", "Luya"], "answer": 1, "fact": "Siling labuyo is small but much hotter than siling haba."},
	{"q": "Which traditional Filipino shaved-ice dessert literally translates to \"mix-mix\"?", "choices": ["Mais con Yelo", "Halo-Halo", "Sago't Gulaman", "Buko Pandan"], "answer": 1, "fact": "You mix the ice, milk, beans, ube and leche flan before eating."},
	{"q": "Sago't gulaman is a cold drink sweetened with...", "choices": ["Arnibal (brown sugar syrup)", "Honey", "Kalamansi juice", "Tsokolate"], "answer": 0, "fact": "Sago are the chewy pearls; gulaman is the jelly."},
	{"q": "Buko pandan is made with young coconut and which fragrant leaf?", "choices": ["Malunggay", "Pandan", "Saluyot", "Dahon ng saging"], "answer": 1, "fact": "Pandan gives the dessert its green color and sweet smell."},
	{"q": "Mais con yelo is shaved ice with milk and...", "choices": ["Corn", "Mango", "Ube", "Langka"], "answer": 0, "fact": "'Mais' is corn and 'yelo' is ice."},
	{"q": "Kalamansi is a small Filipino...", "choices": ["Citrus fruit", "Chili", "Root crop", "Seaweed"], "answer": 0, "fact": "It is squeezed on pancit and used for juice."},
	{"q": "Which sour soup often uses sampalok (tamarind) to make it sour?", "choices": ["Tinola", "Sinigang", "Bulalo", "Nilaga"], "answer": 1, "fact": "Sinigang can also be soured with bayabas, kamias or kalamansi."},
	{"q": "Adobo is usually cooked with vinegar, garlic, pepper and...", "choices": ["Soy sauce", "Coconut milk", "Tomato sauce", "Peanut butter"], "answer": 0, "fact": "Many families add their own twist, like gata or turmeric."},
	{"q": "Which dish is a stew with a thick peanut sauce, served with bagoong?", "choices": ["Kare-kare", "Caldereta", "Menudo", "Afritada"], "answer": 0, "fact": "Bagoong alamang (shrimp paste) is its partner."},
	{"q": "Cebu, famous for its lechon, is part of which island group?", "choices": ["Luzon", "Visayas", "Mindanao", "Batanes"], "answer": 1, "fact": "Cebu lechon is stuffed with lemongrass and spices."},
	{"q": "What is the vinegar commonly used as a dipping sauce in Filipino meals?", "choices": ["Suka", "Patis", "Toyo", "Bagoong"], "answer": 0, "fact": "Sukang Iloko and sukang Paombong are well-known kinds."},
	{"q": "Laing is made from dried leaves of which plant, cooked in coconut milk?", "choices": ["Gabi (taro)", "Kangkong", "Malunggay", "Petsay"], "answer": 0, "fact": "Laing comes from the Bicol Region."},
	{"q": "Which colorful jeep-like vehicle is called the 'King of the Road'?", "choices": ["Tricycle", "Jeepney", "Kalesa", "Pedicab"], "answer": 1, "fact": "Early jeepneys were made from leftover World War II jeeps."},
	{"q": "Mayon Volcano, with its almost perfect cone, is in which province?", "choices": ["Albay", "Batangas", "Bukidnon", "Cebu"], "answer": 0, "fact": "Albay is in the Bicol Region."},
	{"q": "A 'karinderya' is a...", "choices": ["Small eatery serving home-cooked food", "Market for fish", "Bakery", "Rice field"], "answer": 0, "fact": "You point at the dishes you want: turo-turo!"},
	{"q": "Buko juice comes from which fruit?", "choices": ["Young coconut", "Mango", "Pineapple", "Watermelon"], "answer": 0, "fact": "Buko means young coconut."},
]

## Harder questions for the "Huling Hirit" self-thaw: a frozen Tubig with
## no teammate to save them must answer 2 of these in a row.
const HARD := [
	{"q": "In what year was Philippine independence declared in Kawit, Cavite?", "choices": ["1872", "1896", "1898", "1946"], "answer": 2, "fact": "It was declared on June 12, 1898."},
	{"q": "Which galleon trade linked Manila and Mexico for about 250 years?", "choices": ["Manila-Acapulco", "Manila-Seville", "Cebu-Lima", "Manila-Havana"], "answer": 0, "fact": "The galleon trade ran from 1565 to 1815."},
	{"q": "Who led the Katipunan's Magdalo faction?", "choices": ["Andres Bonifacio", "Emilio Aguinaldo", "Antonio Luna", "Gregorio del Pilar"], "answer": 1, "fact": "The rival Magdiwang faction was based in Noveleta, Cavite."},
	{"q": "What is the highest mountain in the Philippines?", "choices": ["Mt. Pulag", "Mt. Apo", "Mt. Dulang-dulang", "Mt. Kitanglad"], "answer": 1, "fact": "Mt. Apo in Mindanao stands about 2,954 m tall."},
	{"q": "In which province are the Batad and Bangaan rice terraces, carved by the Ifugao?", "choices": ["Ifugao", "Benguet", "Mountain Province", "Kalinga"], "answer": 0, "fact": "The Rice Terraces of the Philippine Cordilleras were listed by UNESCO in 1995."},
	{"q": "What is the longest river in the Philippines?", "choices": ["Pasig River", "Agusan River", "Cagayan River", "Pampanga River"], "answer": 2, "fact": "The Cagayan River runs through northern Luzon."},
	{"q": "Which hero wrote 'Mi Último Adiós' before his execution?", "choices": ["Jose Rizal", "Marcelo H. del Pilar", "Graciano Lopez Jaena", "Apolinario Mabini"], "answer": 0, "fact": "Rizal wrote it in Fort Santiago in December 1896."},
	{"q": "Which chieftain defeated Magellan's forces in Mactan in 1521?", "choices": ["Rajah Humabon", "Lapulapu", "Rajah Sulayman", "Tamblot"], "answer": 1, "fact": "The Battle of Mactan happened on April 27, 1521."},
	{"q": "The 'Kudyapi' is a Philippine two-stringed...", "choices": ["Boat lute", "Drum", "Flute", "Gong set"], "answer": 0, "fact": "It is played by groups in Mindanao and Palawan."},
	{"q": "The 'Kulintang' is a set of...", "choices": ["Bamboo flutes", "Small gongs", "Wooden drums", "Shell rattles"], "answer": 1, "fact": "Kulintang gongs are laid in a row on a wooden frame."},
	{"q": "Which Filipino sweet often uses pinipig (pounded young rice) as a topping?", "choices": ["Halo-halo", "Turon", "Leche flan", "Lumpia"], "answer": 0, "fact": "Pinipig adds crunch to halo-halo and ice cream."},
	{"q": "Which city is known as the 'Summer Capital of the Philippines'?", "choices": ["Baguio", "Tagaytay", "Basco", "Malaybalay"], "answer": 0, "fact": "Baguio's cool weather made it the summer capital in 1903."},
	{"q": "The tiny big-eyed primate famous in Bohol is the...", "choices": ["Tarsier", "Tamaraw", "Pilandok", "Binturong"], "answer": 0, "fact": "Philippine tarsiers can turn their heads almost all the way around."},
	{"q": "The tamaraw, a small wild buffalo, is found only on which island?", "choices": ["Mindoro", "Palawan", "Samar", "Negros"], "answer": 0, "fact": "Only a few hundred tamaraw remain in the wild."},
	{"q": "Which language family do most Philippine languages belong to?", "choices": ["Austronesian", "Sino-Tibetan", "Indo-European", "Dravidian"], "answer": 0, "fact": "Austronesian languages stretch from Madagascar to Hawaii."},
	{"q": "Which Filipino general led the Philippine forces in the Battle of Tirad Pass (1899)?", "choices": ["Gregorio del Pilar", "Antonio Luna", "Miguel Malvar", "Artemio Ricarte"], "answer": 0, "fact": "Del Pilar was only 24 years old."},
]

## Bugtong (Filipino riddles) for the Bicol Express pepper checkpoints.
const BUGTONG := [
	{"q": "Bugtong: Isang balong malalim, punong-puno ng patalim. (A deep well full of sharp blades.)", "choices": ["Bibig (Mouth)", "Balon (Well)", "Kutsilyo (Knife)", "Ilong (Nose)"], "answer": 0, "fact": "The 'blades' are the teeth inside the mouth."},
	{"q": "Bugtong: Bahay ni Kaka, hindi matingala. (Kaka's house, you can't look up at it.)", "choices": ["Bubong (Roof)", "Noo (Forehead)", "Langit (Sky)", "Puno (Tree)"], "answer": 1, "fact": "Try looking up at your own forehead!"},
	{"q": "Bugtong: Maliit pa si Kumpare, nakakaakyat na sa tore. (Small Kumpare can already climb the tower.)", "choices": ["Langgam (Ant)", "Unggoy (Monkey)", "Pusa (Cat)", "Ibon (Bird)"], "answer": 0, "fact": "Ants climb walls and towers with ease."},
	{"q": "Bugtong: Baboy ko sa pulo, ang balahibo'y pako. (My pig on the island has nails for hair.)", "choices": ["Langka (Jackfruit)", "Saging (Banana)", "Bayabas (Guava)", "Kasoy (Cashew)"], "answer": 0, "fact": "Jackfruit (langka) has a spiky skin."},
	{"q": "Bugtong: Hindi hari, hindi pari, ang suot ay sari-sari. (Not a king, not a priest, but dressed in many colors.)", "choices": ["Sampayan (Clothesline)", "Bahaghari (Rainbow)", "Paru-paro (Butterfly)", "Parol"], "answer": 0, "fact": "A clothesline 'wears' many kinds of clothes."},
	{"q": "Bugtong: Nagbibigay na, sinasakal pa. (It gives, yet it is choked.)", "choices": ["Bote (Bottle)", "Baka (Cow)", "Gripo (Faucet)", "Puno (Tree)"], "answer": 0, "fact": "You hold a bottle by its 'neck' while it pours."},
	{"q": "Bugtong: Dalawang batong itim, malayo ang tingin. (Two black stones that see far away.)", "choices": ["Mata (Eyes)", "Tenga (Ears)", "Uling (Charcoal)", "Bituin (Stars)"], "answer": 0, "fact": "Eyes are the 'stones' that see far."},
	{"q": "Bugtong: May puno walang bunga, may dahon walang sanga. (Has a trunk but no fruit, has leaves but no branches.)", "choices": ["Aklat (Book)", "Saging (Banana plant)", "Kawayan (Bamboo)", "Walis (Broom)"], "answer": 0, "fact": "A book has 'leaves' (pages) but no branches."},
	{"q": "Bugtong: Heto na si Lelong, bubulong-bulong. (Here comes Grandpa, mumbling and mumbling.)", "choices": ["Bubuyog (Bee)", "Hangin (Wind)", "Radyo", "Lamok (Mosquito)"], "answer": 0, "fact": "Bees buzz like a mumbling lolo."},
	{"q": "Bugtong: Buto't balat, lumilipad. (Bones and skin, yet it flies.)", "choices": ["Saranggola (Kite)", "Paniki (Bat)", "Ibon (Bird)", "Eroplano"], "answer": 0, "fact": "A kite is just a bamboo frame (bones) and paper (skin)."},
	{"q": "Bugtong: Kung kailan mo pinatay, saka pa humaba ang buhay. (Only when you kill it does its life get longer.)", "choices": ["Kandila (Candle)", "Apoy (Fire)", "Ilaw (Lamp)", "Uling (Charcoal)"], "answer": 0, "fact": "Blowing out a candle makes it last longer."},
	{"q": "Bugtong: Isang prinsesa, nakaupo sa tasa. (A princess sitting on a cup.)", "choices": ["Kasoy (Cashew)", "Mangga (Mango)", "Bayabas (Guava)", "Kalamansi"], "answer": 0, "fact": "The cashew nut sits on top of its fruit like a crown."},
	{"q": "Bugtong: Munting tampipi, puno ng salapi. (A small basket full of coins.)", "choices": ["Sili (Chili)", "Ampalaya", "Talong (Eggplant)", "Upo"], "answer": 0, "fact": "The 'coins' are the round seeds inside a sili."},
	{"q": "Bugtong: Isda ko sa Mariveles, nasa loob ang kaliskis. (My fish from Mariveles has its scales inside.)", "choices": ["Sili (Chili)", "Bangus (Milkfish)", "Pinya (Pineapple)", "Saging (Banana)"], "answer": 0, "fact": "Open a sili and its seeds look like scales."},
]
