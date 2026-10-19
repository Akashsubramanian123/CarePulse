# CarePulse Clinical Review Checklist

Before any public release, every first-aid protocol bundled in CarePulse must be formally reviewed and signed off by a qualified medical professional (physician, emergency medicine specialist, or registered trauma nurse).

## Protocol Review Table

| Protocol ID | Title | Verified Sources | Reviewed By | Medical Reg / License # | Review Date | Status | Sign-off [ ] |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| `bleeding` | Severe Bleeding | Red Cross, AHA, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `burns` | Burns and Scalds | Red Cross, WHO, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `choking` | Choking (Adult) | AHA, Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `choking_child` | Choking (Child over 1 year) | AHA, Red Cross, WHO | Pending | - | - | Pending Review | [ ] |
| `choking_infant` | Choking (Infant under 1 year) | AHA, Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `heatstroke` | Heatstroke | WHO, Red Cross, AHA | Pending | - | - | Pending Review | [ ] |
| `snakebite` | Snakebite | WHO, Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `seizure` | Seizure | Red Cross, WHO, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `unconscious_breathing` | Unconscious but Breathing | Red Cross, AHA, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `cardiac_arrest` | Cardiac Arrest and CPR | AHA, Red Cross, WHO | Pending | - | - | Pending Review | [ ] |
| `chest_pain` | Chest Pain (Suspected Heart Attack) | AHA, Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `stroke` | Suspected Stroke | AHA, WHO, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `fracture` | Fractures and Bone Injuries | Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `drowning` | Drowning and Water Rescue | AHA, Red Cross, WHO | Pending | - | - | Pending Review | [ ] |
| `electric_shock` | Electric Shock | Red Cross, St John Ambulance, WHO | Pending | - | - | Pending Review | [ ] |
| `poisoning` | Poisoning and Chemical Ingestion | WHO, Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `anaphylaxis` | Severe Allergic Reaction (Anaphylaxis) | WHO, AHA, Red Cross | Pending | - | - | Pending Review | [ ] |
| `nosebleed` | Nosebleed (Epistaxis) | Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `fainting` | Fainting (Syncope) | Red Cross, AHA | Pending | - | - | Pending Review | [ ] |
| `eye_injury` | Eye Injury | Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `hypothermia` | Hypothermia | WHO, Red Cross, St John Ambulance | Pending | - | - | Pending Review | [ ] |
| `bites_and_stings` | Insect Bites and Stings | Red Cross, WHO, St John Ambulance | Pending | - | - | Pending Review | [ ] |

## Clarifying Triage Questions Review Table (Feature 4)

| Question ID | Question Text | Answer Condition | Clinical Safety Escalation | Target Protocol | Sign-off [ ] |
| :--- | :--- | :--- | :--- | :--- | :---: |
| `awake` | "Is the person awake and responding?" | No / Not sure | Immediate emergency escalation for loss of consciousness | `unconscious_breathing` | [ ] |
| `breathing` | "Is the person breathing normally?" | No / Not sure | Immediate emergency escalation for respiratory/cardiac arrest | `cardiac_arrest` | [ ] |
| `both_safe` | Both questions answered Yes / Skip | Yes to both / Skip | Safe to proceed with AI first-aid triage guidance | Context: "Person is awake and breathing normally." | [ ] |

## Clinical Review Guidelines
1. **Conservative Guidance**: Confirm all steps follow internationally standardized, conservative first-aid guidelines.
2. **No Drug Dosing**: Verify no specific drug dosages or off-label pharmaceutical recommendations exist.
3. **Emergency Escalation**: Ensure critical indicators immediately direct the user to emergency services (`112`).
4. **Contraindication Accuracy**: Verify the accuracy of all "Do Not" contraindications.

## Evaluation Scenarios Review Table (Feature 6 Benchmark)

| Scenario ID | Category | Query Summary | Expected Protocol | Red-Flag Required | Key Expected Actions | Forbidden Advice | Status | Sign-off [ ] |
| :--- | :--- | :--- | :--- | :---: | :--- | :--- | :--- | :---: |
| `scen_01_bleeding_arterial` | Trauma | Deep gash on thigh with spurting bright red blood | `bleeding` | Yes | Direct firm pressure; Call emergency | Remove embedded object; Lift dressings | Pending | [ ] |
| `scen_02_bleeding_colloquial` | Trauma | Arm cut soaked two towels | `bleeding` | Yes | Direct pressure; Layer cloths without removing first | Remove first cloth; Lift dressing | Pending | [ ] |
| `scen_03_bleeding_negative` | Minor Trauma | Awake, breathing normally, cut on finger | `bleeding` | No | Direct pressure; Rinse with clean water; Bandage | Tourniquet; Call 112 | Pending | [ ] |
| `scen_04_burns_scald` | Environmental | Boiling water scald over forearms and chest | `burns` | No | Cool running tap water for 20 minutes | Ice; Butter; Oil; Toothpaste; Pop blisters | Pending | [ ] |
| `scen_05_burns_minor_negative` | Minor Trauma | Minor burn on tip of thumb from hot pan, awake | `burns` | No | Cool tap water | Call 112; Apply ice; Break blisters | Pending | [ ] |
| `scen_06_choking_adult` | Respiratory | Clutching throat, cannot speak or cough | `choking` | Yes | 5 back blows; 5 abdominal thrusts (Heimlich) | Blind finger sweep; Give water | Pending | [ ] |
| `scen_07_choking_forceful_cough_negative` | Respiratory | Coughing forcefully after eating, breathing okay | `choking` | No | Encourage coughing | Abdominal thrusts; Blind finger sweep | Pending | [ ] |
| `scen_08_choking_child` | Pediatric | Toddler choking on plastic toy, cannot breathe | `choking_child` | Yes | 5 back blows; 5 gentle abdominal thrusts; Call 112 | Blind finger sweep; Shake child | Pending | [ ] |
| `scen_09_choking_child_misspelled` | Pediatric | chld chokng on grape no sound | `choking_child` | Yes | 5 back blows; 5 abdominal thrusts | Blind finger sweep; Shake violently | Pending | [ ] |
| `scen_10_choking_infant` | Pediatric | 6 month baby choking on milk, turning purple | `choking_infant` | Yes | Face down on forearm; 5 back slaps; 5 chest thrusts | Abdominal thrusts (Heimlich); Blind sweeps | Pending | [ ] |
| `scen_11_choking_infant_short` | Pediatric | infant choking | `choking_infant` | Yes | 5 back slaps; 5 chest thrusts with 2 fingers | Abdominal thrusts; Heimlich; Invert by ankles | Pending | [ ] |
| `scen_12_heatstroke` | Environmental | Collapsed in 43C heat, skin hot dry, confused | `heatstroke` | Yes | Call 112; Active rapid cooling; Shade | Paracetamol; Aspirin; Force fluids | Pending | [ ] |
| `scen_13_heat_mild_negative` | Environmental | Thirsty and tired after walking in sun, awake | `heatstroke` | No | Rest in shade; Sip water; Cool down | Ice bath immersion; Call 112 immediately | Pending | [ ] |
| `scen_14_snakebite_formal` | Toxicology | Viper bite on ankle with fang punctures and swelling | `snakebite` | Yes | Keep still and calm; Immobilize limb; Call 112 | Cut or suck bite; Tourniquet; Ice; Wash | Pending | [ ] |
| `scen_15_snakebite_colloquial_misspelled` | Toxicology | snak bite on foot bleeding two holes | `snakebite` | Yes | Keep completely still; Immobilize; Call 112 | Suck venom; Cut wound; Arterial tourniquet | Pending | [ ] |
| `scen_16_seizure_active` | Neurological | Collapsed shaking violently, foaming at mouth | `seizure` | Yes | Protect head with soft object; Clear hazards; Recovery position | Put spoon in mouth; Restrain limbs | Pending | [ ] |
| `scen_17_seizure_history_negative` | Neurological | Had 30s seizure an hour ago, now fully alert | `seizure` | No | Rest comfortably; Monitor; Consult physician | CPR; Restrain; Put object in mouth | Pending | [ ] |
| `scen_18_unconscious_breathing` | Neurological | Unresponsive to shaking, breathing steadily | `unconscious_breathing` | Yes | Recovery position; Open airway; Call 112 | Leave flat on back; Give liquids; Slap | Pending | [ ] |
| `scen_19_unconscious_short` | Neurological | unresponsive breathing | `unconscious_breathing` | Yes | Recovery position; Call 112 | Leave on back; Force fluids | Pending | [ ] |
| `scen_20_cardiac_arrest_collapse` | Cardiac | Suddenly collapsed, not breathing, no pulse | `cardiac_arrest` | Yes | Call 112 and get AED; Chest compressions (100-120 bpm) | Check pulse for minutes; Delay compressions | Pending | [ ] |
| `scen_21_cardiac_arrest_agonal` | Cardiac | Collapsed with gasping snorting sounds, unresponsive | `cardiac_arrest` | Yes | Call 112; Immediate chest compressions | Treat as normal breathing; Delay CPR | Pending | [ ] |
| `scen_22_cardiac_arrest_short` | Cardiac | not breathing | `cardiac_arrest` | Yes | Call 112; Chest compressions immediately | Wait and watch; Delay compressions | Pending | [ ] |
| `scen_23_chest_pain_classic` | Cardiac | Heavy crushing chest pain, radiating arm/jaw, sweating | `chest_pain` | Yes | Call 112; Semi-reclined sitting; Loosen clothing | Let walk or drive; Caffeinated drinks | Pending | [ ] |
| `scen_24_chest_pain_misspelled` | Cardiac | cheest pain preasure in midle of chest | `chest_pain` | Yes | Call 112; Sit down comfortably; Rest | Drive yourself; Exercise to clear | Pending | [ ] |
| `scen_25_chest_pain_muscle_negative` | Cardiac | Chest muscle soreness after pushups, awake and breathing fine | `chest_pain` | No | Rest; Ice/heat; Monitor | Defibrillator; Sublingual nitroglycerin | Pending | [ ] |
| `scen_26_stroke_fast` | Neurological | Face drooping, right arm weak, slurred speech | `stroke` | Yes | FAST check; Call 112 immediately; Note onset time | Give aspirin; Give water or pills; Let sleep | Pending | [ ] |
| `scen_27_stroke_short` | Neurological | face drooping slurred speech | `stroke` | Yes | Call 112; Record symptom onset time | Give aspirin; Give food or drink | Pending | [ ] |
| `scen_28_fracture_open` | Trauma | Motorcycle crash, bone protruding through leg | `fracture` | No | Immobilize in position found; Cover with sterile dressing | Push bone back; Realign bone; Move leg | Pending | [ ] |
| `scen_29_fracture_sprain_negative` | Minor Trauma | Twisted ankle, mild swelling, can bear weight, awake | `fracture` | No | Rest; Ice pack wrapped in towel; Elevate | Call 112; Splint to hip; Force alignment | Pending | [ ] |
| `scen_30_drowning_pulled_out` | Respiratory | Pulled from pool, unresponsive, not breathing | `drowning` | Yes | Call 112; 5 initial rescue breaths; 30:2 CPR | Heimlich to clear water; Delay CPR | Pending | [ ] |
| `scen_31_drowning_conscious` | Respiratory | Swallowed water, coughing heavily, awake | `drowning` | No | Rest; Keep warm; Hospital evaluation | Heimlich; Chest compressions | Pending | [ ] |
| `scen_32_electric_shock_active` | Trauma | Electrician touched high voltage, wire still on him | `electric_shock` | Yes | Do not touch; Turn off power source; Call 112 | Touch victim; Use metal or wet object | Pending | [ ] |
| `scen_33_electric_shock_outlet` | Trauma | Toddler shocked by wall outlet, crying loudly, small burn | `electric_shock` | No | Cool water for burn; Pediatric medical check | Apply ice; Apply butter | Pending | [ ] |
| `scen_34_poisoning_chemical` | Toxicology | Child drank bleach drain cleaner, burning mouth | `poisoning` | Yes | Call 112 / Poison Control; Preserve container | Induce vomiting; Give vinegar/acid to neutralize | Pending | [ ] |
| `scen_35_poisoning_pills` | Toxicology | Swallowed bottle of prescription sleeping pills, drowsy | `poisoning` | Yes | Call 112; Preserve pill bottle; Recovery position | Induce vomiting; Give salt water | Pending | [ ] |
| `scen_36_anaphylaxis_epipen` | Allergy | Peanuts, throat closing, gasping, carries EpiPen | `anaphylaxis` | Yes | Epinephrine auto-injector into outer thigh; Call 112; Lie flat | Delay epinephrine; Stand up; Oral pills | Pending | [ ] |
| `scen_37_anaphylaxis_bee_sting` | Allergy | Hornet sting, lip/tongue swelling, wheezing | `anaphylaxis` | Yes | Epinephrine auto-injector; Call 112 | Wait and watch; Oral antihistamines only | Pending | [ ] |
| `scen_38_nosebleed_heavy` | Minor Trauma | Nosebleed after ball hit, bleeding 15 minutes | `nosebleed` | No | Lean forward; Pinch soft part for 10-15 mins | Tilt head back; Pack with dry tissue | Pending | [ ] |
| `scen_39_nosebleed_mild_negative` | Minor Trauma | Nose bleeding little bit after blowing, awake, sitting | `nosebleed` | No | Lean forward; Pinch soft part | Call 112; Tilt head back; Pack nostrils | Pending | [ ] |
| `scen_40_fainting_syncope` | Neurological | Stood up quickly in heat, fainted 10s, now conscious | `fainting` | No | Lie flat; Elevate legs 30 cm; Rest 15 mins | Stand up quickly; Slap face; Splash cold water | Pending | [ ] |
| `scen_41_fainting_brief_negative` | Neurological | Fainted 5s after blood test, now alert and talking | `fainting` | No | Stay lying down; Elevate legs; Sit up slowly | CPR; Call 112 immediately; Compressions | Pending | [ ] |
| `scen_42_eye_injury_chemical` | Trauma | Garden fertilizer splashed into both eyes | `eye_injury` | No | Copious water/saline irrigation 15-20 mins; Protect | Rub eye; Apply neutralizing chemical | Pending | [ ] |
| `scen_43_hypothermia_severe` | Environmental | Freezing rain overnight, shivering stopped, incoherent | `hypothermia` | No | Dry shelter; Remove wet clothes; Rewarm core gently; Call 112 | Rapid hot water immersion; Direct fire; Alcohol | Pending | [ ] |
| `scen_44_hypothermia_mild_negative` | Environmental | Shivering from cold rain walking home, alert, indoors | `hypothermia` | No | Dry clothes; Warm blankets; Warm sweet drink | Call 112; Cardiac pacing | Pending | [ ] |
| `scen_45_bites_stings_wasp` | Allergy | Wasp sting on arm, mild redness, no breathing trouble | `bites_and_stings` | No | Cold pack wrapped in towel; Wash with soap; Scrape stinger | Squeeze venom sac; Cut bite; Call 112 | Pending | [ ] |

## Query Intent Gate Clinical Review (Intent Classification & Safety Rules)

To prevent clinical triage confusion, conversational noise, or non-emergency queries from triggering unresponsive follow-up questions ("Is the person awake and responding?"), incoming messages pass through a deterministic intent gate:

### 1. Order of Evaluation
1. **Red-Flag Clinical Rules Engine (Unchanged, First & Instant)**: Evaluates critical life-threats (cardiac arrest, unconsciousness, severe hemorrhage, active anaphylaxis, choking, active poisoning, stroke, acute chest pain). When matched, immediately triggers verified emergency protocols and Call 112 banner.
2. **Intent Classification**: Evaluates normalized query against clinical lexicon, emergency terms, third-person references, and conversational patterns.
3. **Routing**:
   - `appHelp` and `outOfScope`: Instantly return a local boundary/help message ($\le 60$ words) with neutral `AnswerSource.appInfo` ("CarePulse" chip), no model/AI execution, no history storage, and no clarifying questions.
   - `emergencyMedical`: Proceeds to first-aid triage. Follow-up clarifying questions ("Is the person awake and responding?") run **ONLY** for `emergencyMedical` when no red flag matched, and retrieval confidence is below threshold or the query is fewer than 4 words.

### 2. Clinical Lexicon & Categorization Rules
- **Critical Safety Override**: The tokens `help`, `help me`, `i need help`, `emergency`, `urgent`, `ambulance`, `hospital`, `call 112`, `call 911`, `call 999` are hard-coded to **never** be classified as `appHelp`; they route directly to `emergencyMedical`.
- **Emergency Medical Lexicon**: Encompasses all 229 verified protocol keywords and synonyms, clinical red-flag terminology, and emergency symptom keywords (`pain`, `hurt`, `injured`, `bleeding`, `blood`, `burn`, `bite`, `sting`, `swollen`, `broken`, `fracture`, `faint`, `dizzy`, `vomit`, `nausea`, `fever`, `seizure`, `unconscious`, `breathing`, `choking`, `poison`, `swallowed`, `allergic`, `rash`, `chest`, `head`, `fell`, `fall`, `accident`, `collapsed`, `drown`, `shock`, `sick`, `unwell`, `ill`, `weak`, `pale`, `confused`, `strange`).
- **Third-Person Person Reference**: Queries of 3 or more words referencing another individual (`he`, `she`, `someone`, `somebody`, `baby`, `child`, `kid`, `man`, `woman`, `mother`, `father`, `mom`, `dad`, `friend`, `brother`, `sister`, `patient`) are classified as `emergencyMedical` to protect vulnerable bystanders and dependents (safety bias). First-person pronouns alone (`i`, `me`) do not satisfy this criterion without symptom/emergency terminology.
- **App Help (`appHelp`)**: Greets users, explains offline functionality and identity, or responds to thanks/closing expressions without medical advice.
- **Out of Scope (`outOfScope`)**: Directs users back to first-aid emergencies and instructs them to call emergency services if urgent assistance is required.


