from flask import Flask, render_template, request, jsonify
import json, os, uuid, re
from datetime import datetime
import requests as http

app = Flask(__name__)
DATA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cookbook_data.json')

# ── Data helpers ──────────────────────────────────────────────────────────────

def load():
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE) as f:
            return json.load(f)
    return _default()

def save(data):
    with open(DATA_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def _default():
    return {
        'pantry': [],
        'recipes': [],
        'mealplan': {str(i): {'breakfast': None, 'lunch': None, 'dinner': None} for i in range(7)},
        'preferences': {
            'apiKey': '', 'userName': '', 'allergies': [], 'dietary': [],
            'disliked': [], 'avoidFromRatings': [], 'skillLevel': 'Intermediate',
            'maxCookTime': 60, 'defaultServings': 4, 'favoriteCuisines': []
        }
    }

# ── Main page ─────────────────────────────────────────────────────────────────

@app.route('/')
def index():
    return render_template('index.html')

# ── Pantry ────────────────────────────────────────────────────────────────────

@app.route('/api/pantry', methods=['GET'])
def get_pantry():
    return jsonify(load()['pantry'])

@app.route('/api/pantry', methods=['POST'])
def add_pantry():
    d = load()
    item = request.json
    item['id'] = str(uuid.uuid4())
    item['dateAdded'] = datetime.now().isoformat()
    d['pantry'].append(item)
    save(d)
    return jsonify(item)

@app.route('/api/pantry/<item_id>', methods=['PUT'])
def update_pantry(item_id):
    d = load()
    for i, item in enumerate(d['pantry']):
        if item['id'] == item_id:
            d['pantry'][i].update(request.json)
            save(d)
            return jsonify(d['pantry'][i])
    return jsonify({'error': 'Not found'}), 404

@app.route('/api/pantry/<item_id>', methods=['DELETE'])
def delete_pantry(item_id):
    d = load()
    d['pantry'] = [i for i in d['pantry'] if i['id'] != item_id]
    save(d)
    return jsonify({'ok': True})

# ── Recipes ───────────────────────────────────────────────────────────────────

@app.route('/api/recipes', methods=['GET'])
def get_recipes():
    return jsonify(load()['recipes'])

@app.route('/api/recipes/<recipe_id>', methods=['PUT'])
def update_recipe(recipe_id):
    d = load()
    for i, r in enumerate(d['recipes']):
        if r['id'] == recipe_id:
            d['recipes'][i].update(request.json)
            save(d)
            return jsonify(d['recipes'][i])
    return jsonify({'error': 'Not found'}), 404

@app.route('/api/recipes/<recipe_id>', methods=['DELETE'])
def delete_recipe(recipe_id):
    d = load()
    d['recipes'] = [r for r in d['recipes'] if r['id'] != recipe_id]
    save(d)
    return jsonify({'ok': True})

# ── AI Generation ─────────────────────────────────────────────────────────────

@app.route('/api/generate', methods=['POST'])
def generate():
    d = load()
    prefs = d['preferences']
    body = request.json
    api_key = prefs.get('apiKey', '')
    if not api_key:
        return jsonify({'error': 'API key not set. Go to Settings first.'}), 400

    pantry = d['pantry']
    count = body.get('count', 3)
    meal_type = body.get('mealType', '')
    cuisine_hint = body.get('cuisineHint', '')
    use_pantry = body.get('usePantry', True)

    pantry_list = ', '.join(
        f"{i['name']} ({i.get('quantity','')} {i.get('unit','')})" for i in pantry
    ) if use_pantry and pantry else 'common kitchen staples'

    exclusions = ', '.join(
        prefs.get('allergies', []) + prefs.get('disliked', []) + prefs.get('avoidFromRatings', [])
    ) or 'none'
    dietary = ', '.join(prefs.get('dietary', [])) or 'none'

    system = ("You are a professional chef and nutritionist. Generate creative, delicious recipes "
              "based on pantry ingredients and user preferences. Respond with valid JSON only.")

    user = f"""Generate {count} unique recipe{'s' if count > 1 else ''} using: {pantry_list}

Preferences:
- Skill level: {prefs.get('skillLevel', 'Intermediate')}
- Max cook time: {prefs.get('maxCookTime', 60)} minutes
- Dietary restrictions: {dietary}
- Exclude (allergies/dislikes/low-rated): {exclusions}
- Default servings: {prefs.get('defaultServings', 4)}
{"- Meal type: " + meal_type if meal_type else ""}
{"- Preferred cuisine: " + cuisine_hint if cuisine_hint else ""}

Respond ONLY with a JSON array:
[{{"name":"","description":"","cuisineType":"","tags":[],"prepTime":0,"cookTime":0,"servings":4,
"ingredients":[{{"name":"","amount":0.0,"unit":""}}],
"instructions":[{{"instruction":"","timerMinutes":null}}],
"nutritionInfo":{{"calories":0,"protein":0.0,"carbohydrates":0.0,"fat":0.0,"fiber":0.0}}}}]

Include timerMinutes (integer) on steps that require timed cooking, otherwise null."""

    try:
        text = _claude(api_key, system, user)
        match = re.search(r'\[.*\]', text, re.DOTALL)
        if not match:
            return jsonify({'error': 'Could not parse AI response. Try again.'}), 500
        raw = json.loads(match.group())
        saved = []
        for r in raw:
            r['id'] = str(uuid.uuid4())
            r['dateCreated'] = datetime.now().isoformat()
            r['rating'] = None
            r['isFavorite'] = False
            d['recipes'].insert(0, r)
            saved.append(r)
        save(d)
        return jsonify(saved)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/extract-ingredients', methods=['POST'])
def extract_ingredients():
    d = load()
    api_key = d['preferences'].get('apiKey', '')
    recipe = request.json.get('recipe', {})
    if not api_key:
        return jsonify([])
    ing_list = ', '.join(i['name'] for i in recipe.get('ingredients', []))
    try:
        text = _claude(
            api_key,
            "Culinary expert. Respond with valid JSON only.",
            f'Recipe "{recipe.get("name")}" has: {ing_list}. '
            f'List 3-5 most distinctive flavor-defining ingredients as a JSON array of strings only.'
        )
        match = re.search(r'\[.*?\]', text, re.DOTALL)
        if match:
            return jsonify(json.loads(match.group()))
    except:
        pass
    return jsonify([])

# ── Meal Plan ─────────────────────────────────────────────────────────────────

@app.route('/api/mealplan', methods=['GET'])
def get_mealplan():
    return jsonify(load()['mealplan'])

@app.route('/api/mealplan', methods=['PUT'])
def update_mealplan():
    d = load()
    d['mealplan'] = request.json
    save(d)
    return jsonify(d['mealplan'])

# ── Shopping List ─────────────────────────────────────────────────────────────

@app.route('/api/shopping', methods=['GET'])
def shopping_list():
    d = load()
    recipes_map = {r['id']: r for r in d['recipes']}
    agg = {}
    for day in d['mealplan'].values():
        for slot in ['breakfast', 'lunch', 'dinner']:
            meal = day.get(slot)
            if not meal or not meal.get('recipeId'):
                continue
            recipe = recipes_map.get(meal['recipeId'])
            if not recipe:
                continue
            scale = meal.get('servings', recipe.get('servings', 4)) / max(recipe.get('servings', 4), 1)
            for ing in recipe.get('ingredients', []):
                key = ing['name'].lower()
                if key in agg:
                    agg[key]['amount'] = round(agg[key]['amount'] + ing['amount'] * scale, 1)
                else:
                    agg[key] = {'name': ing['name'], 'amount': round(ing['amount'] * scale, 1), 'unit': ing['unit']}
    return jsonify(sorted(agg.values(), key=lambda x: x['name']))

# ── Preferences ───────────────────────────────────────────────────────────────

@app.route('/api/preferences', methods=['GET'])
def get_preferences():
    return jsonify(load()['preferences'])

@app.route('/api/preferences', methods=['PUT'])
def update_preferences():
    d = load()
    d['preferences'].update(request.json)
    save(d)
    return jsonify(d['preferences'])

# ── Claude API ────────────────────────────────────────────────────────────────

def _claude(api_key, system_prompt, user_prompt):
    resp = http.post(
        'https://api.anthropic.com/v1/messages',
        headers={
            'Content-Type': 'application/json',
            'x-api-key': api_key,
            'anthropic-version': '2023-06-01'
        },
        json={
            'model': 'claude-opus-4-7',
            'max_tokens': 4096,
            'system': [{'type': 'text', 'text': system_prompt, 'cache_control': {'type': 'ephemeral'}}],
            'messages': [{'role': 'user', 'content': user_prompt}]
        },
        timeout=90
    )
    resp.raise_for_status()
    return resp.json()['content'][0]['text']

# ─────────────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    print("🍳  Cookbook running at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
