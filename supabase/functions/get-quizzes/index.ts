import { corsPreflight, errorResponse, jsonResponse, verifyAuth } from "../_shared/supabase_client.ts";
import { redis } from "../_shared/redis.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return corsPreflight();
  }

  if (req.method !== "GET" && req.method !== "POST") {
    return errorResponse("Method Not Allowed", 405);
  }

  const { user, error: authError } = await verifyAuth(req);
  if (authError || !user) {
    return errorResponse(authError || "Unauthorized", 401);
  }

  const cacheKey = `quizzes:categories`;
  const cached = await redis.get(cacheKey);

  if (cached) {
    const parsed = typeof cached === "string" ? JSON.parse(cached) : cached;
    return jsonResponse(parsed, 200, { "Cache-Control": "public, max-age=10, s-maxage=30", "X-Cache": "HIT" });
  }

  // Fallback to mock data if not in cache (could be fetched from Postgres later)
  const categories = [
    {
      id: 'science',
      title: 'Science & Space',
      description: 'Test your knowledge of the universe.',
      icon: '🔬',
      bgColor: '#2ECC71',
      questions: [
        { text: 'What planet is known as the Red Planet?', correctAnswer: 'Mars', options: ['Venus', 'Mars', 'Jupiter', 'Saturn'] },
        { text: 'What gas do plants absorb from the air?', correctAnswer: 'CO₂', options: ['Oxygen', 'Nitrogen', 'CO₂', 'Helium'] },
        { text: 'What is the hardest natural substance?', correctAnswer: 'Diamond', options: ['Gold', 'Iron', 'Diamond', 'Quartz'] },
        { text: 'What is the boiling point of water in °C?', correctAnswer: '100', options: ['90', '100', '110', '120'] },
        { text: 'Which planet is closest to the Sun?', correctAnswer: 'Mercury', options: ['Venus', 'Mercury', 'Earth', 'Mars'] },
        { text: 'What is the chemical symbol for gold?', correctAnswer: 'Au', options: ['Ag', 'Au', 'Fe', 'Cu'] },
        { text: 'What is the speed of light (km/s)?', correctAnswer: '300,000', options: ['150,000', '300,000', '450,000', '600,000'] },
        { text: 'Which element has symbol "O"?', correctAnswer: 'Oxygen', options: ['Gold', 'Osmium', 'Oxygen', 'Oganesson'] },
        { text: 'What is the largest planet in our solar system?', correctAnswer: 'Jupiter', options: ['Saturn', 'Jupiter', 'Neptune', 'Uranus'] },
        { text: 'Which vitamin does the Sun give us?', correctAnswer: 'Vitamin D', options: ['Vitamin A', 'Vitamin B', 'Vitamin C', 'Vitamin D'] }
      ]
    },
    {
      id: 'geography',
      title: 'Geography & History',
      description: 'Explore the world and its past.',
      icon: '🌍',
      bgColor: '#3498DB',
      questions: [
        { text: 'How many continents are there on Earth?', correctAnswer: '7', options: ['5', '6', '7', '8'] },
        { text: 'What is the largest ocean on Earth?', correctAnswer: 'Pacific', options: ['Atlantic', 'Indian', 'Pacific', 'Arctic'] },
        { text: 'Which country has the most people?', correctAnswer: 'India', options: ['USA', 'China', 'India', 'Brazil'] },
        { text: 'What is the capital of Japan?', correctAnswer: 'Tokyo', options: ['Osaka', 'Tokyo', 'Kyoto', 'Nagoya'] },
        { text: 'What year did World War II end?', correctAnswer: '1945', options: ['1942', '1944', '1945', '1946'] },
        { text: 'Which language has the most speakers?', correctAnswer: 'English', options: ['Spanish', 'English', 'Mandarin', 'Hindi'] },
        { text: 'What is the tallest mountain in the world?', correctAnswer: 'Mount Everest', options: ['K2', 'Mount Everest', 'Kilimanjaro', 'Denali'] },
        { text: 'Which river is the longest in the world?', correctAnswer: 'Nile', options: ['Amazon', 'Nile', 'Yangtze', 'Mississippi'] }
      ]
    },
    {
      id: 'biology',
      title: 'Animals & Biology',
      description: 'Discover the living world.',
      icon: '🦁',
      bgColor: '#E67E22',
      questions: [
        { text: 'Which animal is the tallest in the world?', correctAnswer: 'Giraffe', options: ['Elephant', 'Giraffe', 'Horse', 'Camel'] },
        { text: 'How many legs does a spider have?', correctAnswer: '8', options: ['6', '8', '10', '12'] },
        { text: 'How many bones are in the human body?', correctAnswer: '206', options: ['196', '206', '216', '226'] },
        { text: 'What is the largest land animal?', correctAnswer: 'Elephant', options: ['Rhino', 'Hippo', 'Elephant', 'Bear'] },
        { text: 'Which organ pumps blood in the body?', correctAnswer: 'Heart', options: ['Brain', 'Lungs', 'Heart', 'Liver'] },
        { text: 'What do pandas primarily eat?', correctAnswer: 'Bamboo', options: ['Fish', 'Bamboo', 'Insects', 'Fruits'] },
        { text: 'Which bird can fly backwards?', correctAnswer: 'Hummingbird', options: ['Eagle', 'Pigeon', 'Hummingbird', 'Woodpecker'] }
      ]
    },
    {
      id: 'general',
      title: 'General & Math',
      description: 'A mix of brain teasers and facts.',
      icon: '🧠',
      bgColor: '#9B5CFF',
      questions: [
        { text: 'What is the smallest prime number?', correctAnswer: '2', options: ['0', '1', '2', '3'] },
        { text: 'How many colors are in a rainbow?', correctAnswer: '7', options: ['5', '6', '7', '8'] },
        { text: 'How many hours are in a day?', correctAnswer: '24', options: ['12', '24', '36', '48'] },
        { text: 'How many sides does a hexagon have?', correctAnswer: '6', options: ['5', '6', '7', '8'] },
        { text: 'What is the square root of 144?', correctAnswer: '12', options: ['10', '12', '14', '16'] },
        { text: 'What is 15% of 200?', correctAnswer: '30', options: ['15', '20', '30', '45'] }
      ]
    }
  ];

  // Cache indefinitely or for a long time (1 hour here)
  await redis.setex(cacheKey, 3600, JSON.stringify(categories));

  return jsonResponse(categories, 200, { "Cache-Control": "public, max-age=60, s-maxage=3600", "X-Cache": "MISS" });
});
