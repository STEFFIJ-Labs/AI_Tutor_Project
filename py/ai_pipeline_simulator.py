import psycopg2

def simulate_ai_pipeline():
    print("\n" + "="*50)
    print("🧠 AI TUTOR PIPELINE SIMULATOR - INITIALIZATION")
    print("="*50)
    
    try:
        conn = psycopg2.connect(dbname="ai_tutor_db", user="postgres")
        cur = conn.cursor()
        print("[+] Connection to the 'Deep Knowledge Core' established successfully.")
        
        query = """
            SELECT content_raw, syntax_ud_json 
            FROM CONTENT_UNIT;
        """
        cur.execute(query)
        rows = cur.fetchall()

        for row in rows:
            target_phrase = row[0]
            syntax_json = row[1] 
            
            print(f"\n[Target Content]: '{target_phrase}'")
            print("[AI Parser] Extracting syntax tree (JSONB to Python Dict):")
            
            if syntax_json and "dependencies" in syntax_json:
                for dep in syntax_json["dependencies"]:
                    print(f"   -> Syntactic Relation: [{dep['rel'].upper()}] anchored to token '{dep['word']}'")

        cur.close()
        conn.close()
        print("\n" + "="*50)
        print("✅ PIPELINE PROCESSING COMPLETED")
        print("="*50 + "\n")

    except Exception as e:
        print(f"\n[!] CRITICAL SYSTEM ERROR: {e}\n")

if __name__ == "__main__":
    simulate_ai_pipeline()
