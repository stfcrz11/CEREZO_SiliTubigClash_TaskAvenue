extends RefCounted
## Question bank: Filipino culture (mythology, epics, traditions, games).
## Each entry: q = question, choices = 4 options, answer = index of the
## correct option in choices, fact = short note shown after answering.
## Add or edit entries freely; the game draws them at random.

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
]
