-- Define where bounty jobs can be accepted (coordinates)
-- Typically located in Police stations
bountyLocations = {
  {x = 441.08, y = -981.33, z = 30.69},
}

-- Define criminals with their bounties and skill levels each
-- alertnessModifier = Set alertness (value ranges from 0 to 3)
-- accuracyModifier = Set accuracy 0-100 (default is 50)
-- deadOrAlive is pending code usage.. currently inactive
-- If vehicle_model is passed, it will load the PED into the vehicle
bounties = {
  {
    name = "John Doe",
    model = "a_m_m_hillbilly_01",
    story = "a deer, a female deer",
    reward = 1800,
    deadOrAlive = "Alive",
    primaryWeapon = "WEAPON_PISTOL",
    alertnessModifier = 2,
    accuracyModifier = 40,
    vehicle_model = "cheetah",
  },
  {
    name = "Zoie Smith",
    model = "a_f_y_bevhills_04",
    story = "its a long story",
    reward = 1750,
    deadOrAlive = "Alive",
    primaryWeapon = "WEAPON_SMG",
    alertnessModifier = 1,
    accuracyModifier = 50,
    vehicle_model = "gauntlet",
  },
  {
    name = "Bobby the Stickman",
    model = "u_m_m_streetart_01",
    story = "he stuck it to the man",
    reward = 2500,
    deadOrAlive = "Alive",
    primaryWeapon = "WEAPON_NIGHTSTICK",
    alertnessModifier = 0,
    accuracyModifier = 75,
  },
  {
    name = "Emily Wilkerson",
    model = "g_f_y_vagos_01",
    story = "she did something horrible",
    reward = 5000,
    deadOrAlive = "Dead or Alive",
    primaryWeapon = "WEAPON_HEAVYSNIPER",
    alertnessModifier = 1,
    accuracyModifier = 60,
  },
  {
    name = "Thomas Harris",
    model = "a_m_m_skater_01",
    story = "its a long story",
    reward = 3800,
    deadOrAlive = "Dead or Alive",
    primaryWeapon = "WEAPON_ASSAULTRIFLE",
    alertnessModifier = 3,
    accuracyModifier = 70,
    vehicle_model = "oppressor2",
  },
  {
    name = "Bunny Foo Foo",
    model = "a_f_m_fatcult_01",
    story = "hop hop hop",
    reward = 600,
    deadOrAlive = "Dead or Alive",
    primaryWeapon = "WEAPON_MACHETE",
    alertnessModifier = 3,
    accuracyModifier = 60,
  },
  {
    name = "Bruce Batty",
    model = "u_m_y_babyd",
    story = "a hitman",
    reward = 1200,
    deadOrAlive = "Dead or Alive",
    primaryWeapon = "WEAPON_BAT",
    alertnessModifier = 1,
    accuracyModifier = 45,
  },
}
