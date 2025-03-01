/mob/living/simple_animal/construct
	name = "Construct"
	real_name = "Construct"
	desc = ""
	icon = 'icons/mob/construct.dmi'
	speak_emote = list("hisses")
	emote_hear = list("wails","screeches")
	response_help  = "thinks better of touching"
	response_disarm = "flails at"
	response_harm = "punches"
	icon_dead = "shade_dead"
	speed = -1
	a_intent = INTENT_HARM
	stop_automated_movement = TRUE
	status_flags = CANPUSH
	universal_speak = 1
	min_oxy = 0
	max_oxy = 0
	min_tox = 0
	max_tox = 0
	min_co2 = 0
	max_co2 = 0
	min_n2 = 0
	max_n2 = 0
	minbodytemp = 0
	faction = "cult"
	var/list/construct_spells = list()

	animalistic = FALSE
	has_head = TRUE
	has_arm = TRUE

/mob/living/simple_animal/construct/atom_init()
	attack_sound = SOUNDIN_PUNCH_MEDIUM
	. = ..()
	name = text("[initial(name)] ([rand(1, 1000)])")
	real_name = name
	for(var/spell in construct_spells)
		AddSpell(new spell(src))

	var/obj/effect/effect/forcefield/rune/R = new
	AddComponent(/datum/component/forcefield, "blood aura", 20, 5 SECONDS, 3 SECONDS, R, TRUE, TRUE)
	SEND_SIGNAL(src, COMSIG_FORCEFIELD_PROTECT, src)

	var/image/glow = image(icon, src, "glow_[icon_state]", ABOVE_LIGHTING_LAYER)
	glow.plane = ABOVE_LIGHTING_PLANE
	add_overlay(glow)

	ADD_TRAIT(src, TRAIT_ARIBORN, TRAIT_ARIBORN_FLYING)

/mob/living/simple_animal/construct/death()
	..()
	new /obj/item/weapon/reagent_containers/food/snacks/ectoplasm(src.loc)
	visible_message("<span class='red'>[src] collapses in a shattered heap.</span>")
	ghostize(bancheck = TRUE)
	qdel(src)

/mob/living/simple_animal/construct/ghostize(can_reenter_corpse, bancheck)
	if(!QDELETED(src) && key && ckey)
		qdel(src)
	. = ..()

/mob/living/simple_animal/construct/examine(mob/user)
	var/msg = "<span cass='info'>*---------*\nThis is [bicon(src)] \a <EM>[src]</EM>!\n"
	if (src.health < src.maxHealth)
		msg += "<span class='warning'>"
		if (src.health >= src.maxHealth/2)
			msg += "It looks slightly dented.\n"
		else
			msg += "<B>It looks severely dented!</B>\n"
		msg += "</span>"

	if(w_class)
		msg += "It is a [get_size_flavor()] sized creature.\n"

	msg += "*---------*</span>"
	to_chat(user, msg)

/mob/living/simple_animal/construct/attack_animal(mob/living/simple_animal/M)
	if(istype(M, /mob/living/simple_animal/construct/builder) && health <  maxHealth)
		health += min(health + 5, maxHealth)
		med_hud_set_health()
		M.visible_message("[M] mends some of the <EM>[src]'s</EM> wounds.")
		return
	return ..()

/////////////////Juggernaut///////////////
/mob/living/simple_animal/construct/armoured
	name = "Juggernaut"
	real_name = "Juggernaut"
	desc = "A possessed suit of armour driven by the will of the restless dead."
	icon_state = "juggernaut"
	icon_living = "juggernaut"
	maxHealth = 200
	health = 200
	response_harm = "harmlessly punches"
	harm_intent_damage = 0
	melee_damage = 25
	attacktext = "smash"
	speed = 3
	w_class = SIZE_MASSIVE
	environment_smash = 2
	status_flags = 0
	construct_spells = list(
			/obj/effect/proc_holder/spell/aoe_turf/conjure/lesserforcewall,
			)

/mob/living/simple_animal/construct/armoured/atom_init()
	attack_sound = SOUNDIN_PUNCH_VERYHEAVY
	. = ..()
	var/obj/effect/effect/forcefield/rune/R = new
	AddComponent(/datum/component/forcefield, "strong blood aura", 80, 5 SECONDS, 6 SECONDS, R, TRUE, TRUE)
	SEND_SIGNAL(src, COMSIG_FORCEFIELD_PROTECT, src)

/mob/living/simple_animal/construct/armoured/bullet_act(obj/item/projectile/P, def_zone)
	if(istype(P, /obj/item/projectile/energy) || istype(P, /obj/item/projectile/beam))
		var/reflectchance = 80 - round(P.damage/3)
		if(prob(reflectchance))
			adjustBruteLoss(P.damage * 0.5)
			visible_message("<span class='danger'>The [P.name] gets reflected by [src]'s shell!</span>", \
							"<span class='userdanger'>The [P.name] gets reflected by [src]'s shell!</span>")

			// Find a turf near or on the original location to bounce to
			if(P.starting)
				var/new_x = P.starting.x + pick(0, 0, -1, 1, -2, 2, -2, 2, -2, 2, -3, 3, -3, 3)
				var/new_y = P.starting.y + pick(0, 0, -1, 1, -2, 2, -2, 2, -2, 2, -3, 3, -3, 3)
				var/turf/curloc = get_turf(src)

				// redirect the projectile
				P.redirect(new_x, new_y, curloc, src)

			return PROJECTILE_FORCE_MISS // complete projectile permutation

	return ..()


////////////////////////Wraith/////////////////////////////////////////////
/mob/living/simple_animal/construct/wraith
	name = "Wraith"
	real_name = "Wraith"
	desc = "A wicked bladed shell contraption piloted by a bound spirit."
	icon_state = "wraith"
	icon_living = "wraith"
	maxHealth = 75
	health = 75
	melee_damage = 20
	attacktext = "slash"
	speed = -1
	see_in_dark = 7
	attack_sound = list('sound/weapons/bladeslice.ogg')
	attack_push_vis_effect = ATTACK_EFFECT_SLASH
	attack_disarm_vis_effect = ATTACK_EFFECT_SLASH
	construct_spells = list(
		/obj/effect/proc_holder/spell/targeted/ethereal_jaunt/phaseshift,
		)


/////////////////////////////Artificer/////////////////////////
/mob/living/simple_animal/construct/builder
	name = "Artificer"
	real_name = "Artificer"
	desc = "A bulbous construct dedicated to building and maintaining The Cult of Nar-Sie's armies."
	icon_state = "artificer"
	icon_living = "artificer"
	maxHealth = 50
	health = 50
	response_harm = "viciously beats"
	harm_intent_damage = 5
	melee_damage = 10
	attacktext = "ramm"
	speed = -0.2
	environment_smash = 2
	construct_spells = list(
		/obj/effect/proc_holder/spell/aoe_turf/conjure/construct/lesser,
		/obj/effect/proc_holder/spell/aoe_turf/conjure/door,
		/obj/effect/proc_holder/spell/aoe_turf/conjure/wall,
		/obj/effect/proc_holder/spell/aoe_turf/conjure/floor,
		/obj/effect/proc_holder/spell/aoe_turf/conjure/soulstone,
		)

/mob/living/simple_animal/construct/builder/atom_init()
	attack_sound = SOUNDIN_PUNCH_MEDIUM
	. = ..()
	var/datum/atom_hud/data/medical/adv/hud = global.huds[DATA_HUD_MEDICAL_ADV]
	hud.add_hud_to(src)

/////////////////////////////Behemoth/////////////////////////
/mob/living/simple_animal/construct/behemoth
	name = "Behemoth"
	real_name = "Behemoth"
	desc = "The pinnacle of occult technology, Behemoths are the ultimate weapon in the Cult of Nar-Sie's arsenal."
	icon_state = "juggernaut"
	icon_living = "juggernaut"
	maxHealth = 10
	health = 10
	speak_emote = list("rumbles")
	response_harm = "harmlessly punches"
	harm_intent_damage = 0
	melee_damage = 50
	attacktext = "brutally crush"
	speed = 5
	environment_smash = 2
	w_class = SIZE_MASSIVE
	resize = 1.2

/mob/living/simple_animal/construct/behemoth/atom_init()
	attack_sound = SOUNDIN_PUNCH_HEAVY
	. = ..()
	var/obj/effect/effect/forcefield/rune/R = new
	AddComponent(/datum/component/forcefield, "strong blood aura", 500, 30 SECONDS, 10 SECONDS, R, TRUE, TRUE)
	SEND_SIGNAL(src, COMSIG_FORCEFIELD_PROTECT, src)


/////////////////////////////////////Harvester construct/////////////////////////////////
/mob/living/simple_animal/construct/harvester
	name = "Harvester"
	real_name = "Harvester"
	desc = "A harbinger of Nar-Sie's enlightenment. It'll be all over soon."
	icon_state = "harvester"
	icon_living = "harvester"
	maxHealth = 60
	health = 60
	melee_damage = 8
	attacktext = "prodd"
	speed = 0
	environment_smash = 1
	see_in_dark = 7
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE
	density = FALSE
	attack_sound = list('sound/weapons/slash.ogg')
	attack_push_vis_effect = ATTACK_EFFECT_SLASH
	attack_disarm_vis_effect = ATTACK_EFFECT_SLASH
	pass_flags = PASSTABLE
	construct_spells = list(
		/obj/effect/proc_holder/spell/aoe_turf/conjure/smoke,
		/obj/effect/proc_holder/spell/no_target/area_conversion,
		)

/mob/living/simple_animal/construct/harvester/Bump(atom/A)
	. = ..()
	if(A == loc)
		return
	var/its_wall = FALSE
	if(istype(A, /turf/simulated/wall/cult))
		its_wall = TRUE

	if(its_wall || istype(A, /obj/structure/mineral_door/cult) || istype(A, /obj/structure/cult) || isconstruct(A) || istype(A, /mob/living/simple_animal/hostile/pylon))
		var/atom/movable/stored_pulling = pulling
		if(stored_pulling)
			stored_pulling.set_dir(get_dir(stored_pulling.loc, loc))
			stored_pulling.forceMove(loc)

		if(its_wall)
			forceMove(A)
		else
			forceMove(A.loc)

		if(stored_pulling)
			start_pulling(stored_pulling) //drag anything we're pulling through the wall with us by magic

/mob/living/simple_animal/construct/harvester/Process_Spacemove(movement_dir = 0)
	return TRUE

/mob/living/simple_animal/construct/harvester/UnarmedAttack(atom/A)
	if(ishuman(A) && prob(20))
		if(get_targetzone() == BP_HEAD) // No
			return ..()
		var/mob/living/carbon/human/C = A
		var/obj/item/organ/external/BP = C.get_bodypart(get_targetzone())
		if(BP && !BP.droplimb(FALSE, FALSE, DROPLIMB_EDGE))
			return ..() //Attack
		return
	return ..()

/////////////////////////////////////Proteon from tg/////////////////////////////////
/mob/living/simple_animal/construct/proteon
	name = "Proteon"
	real_name = "Proteon"
	desc = "A weaker construct meant to scour ruins for objects of Nar'Sie's affection. Those barbed claws are no joke."
	icon_state = "proteon"
	icon_living = "proteon"
	maxHealth = 30
	health = 30
	melee_damage = 35
	speed = -2
	response_harm = "pinch"

	sight = SEE_MOBS

/mob/living/simple_animal/construct/proteon/atom_init()
	attack_sound = SOUNDIN_PUNCH_HEAVY
	. = ..()


/////////////////////////////////////Charged Pylon not construct/////////////////////////////////
/mob/living/simple_animal/hostile/pylon
	name = "charged pylon"
	real_name = "charged pylon"
	desc = "A floating crystal that hums with an unearthly energy."
	icon = 'icons/obj/cult.dmi'
	icon_state = "pylon_glow"
	icon_living = "pylon"
	ranged = TRUE
	amount_shoot = 3
	projectiletype = /obj/item/projectile/beam/cult_laser
	projectilesound = 'sound/weapons/guns/gunpulse_laser.ogg'
	ranged_cooldown = 5
	ranged_cooldown_cap = 0
	maxHealth = 200
	health = 200
	melee_damage = 0
	speed = 0
	anchored = TRUE
	stop_automated_movement = TRUE
	canmove = FALSE
	faction = "cult"
	var/timer

/mob/living/simple_animal/hostile/pylon/atom_init()
	. = ..()
	friends = global.cult_religion?.members

/mob/living/simple_animal/hostile/pylon/death(gibbed)
	. = ..()
	for(var/atom/A in contents)
		qdel(A)
	qdel(src)

/mob/living/simple_animal/hostile/pylon/proc/deactivate()
	for(var/obj/structure/cult/pylon/P in contents)
		P.update_integrity(health)
		P.forceMove(loc)
	qdel(src)

/mob/living/simple_animal/hostile/pylon/proc/add_friend(datum/religion/R, mob/M, holy_role)
	friends = R.members

/mob/living/simple_animal/hostile/pylon/attackby(obj/item/I, mob/user, params)
	if(iscultist(user))
		if(istype(I, /obj/item/weapon/storage/bible/tome))
			deactivate()
			deltimer(timer)
	else
		return ..()

/mob/living/simple_animal/hostile/pylon/update_canmove()
	return
