
//generic (by snowflake) tile smoothing code; smooth your icons with this (modified for TauCetiClassic)!
/*
	Main difference between tgstation's smoothing and this modified version, as each tile is no more devided in 4 corners,
	Instead of overlays, single fulltile icon generated in the process which is similar to baystation's smoothing (why? overlays put more stress into client's renderer).
	To use this, just set your atom's 'smooth' var to SMOOTH_TRUE (see other defines for that var for more control).
	If your atom can be moved/unanchored, set its 'can_be_unanchored' var to TRUE.
	If you don't want your atom's icon to smooth with anything but atoms of the same type, set the list 'canSmoothWith' to null;
	Otherwise, put all types you want the atom icon to smooth with in 'canSmoothWith' INCLUDING THE TYPE OF THE ATOM ITSELF.

	Each atom has its own source icon file with which is used in the process to generate proper icon states. See 'icons\turf\smooth_example\' folder for templates.

	DIAGONAL SMOOTHING INSTRUCTIONS
	To make your atom smooth diagonally you need all the proper icon states (see 'smooth_wall_diagonal.dmi' for a template) and
	to add the 'SMOOTH_DIAGONAL' flag to the atom's smooth var (in addition to either SMOOTH_TRUE or SMOOTH_MORE).

	For turfs, what appears under the diagonal corners depends on the turf that was in the same position previously: if you make a wall on
	a plating floor, you will see plating under the diagonal wall corner, if it was space, you will see space.

	If you wish to map a diagonal wall corner with a fixed underlay, you must configure the turf's 'fixed_underlay' list var, like so:
		fixed_underlay = list("icon"='icon_file.dmi', "icon_state"="iconstatename")
	A non null 'fixed_underlay' list var will skip copying the previous turf appearance and always use the list. If the list is
	not set properly, the underlay will default to regular floor plating.

	To see an example of a diagonal wall, see 'no example >:|' and its subtypes.
*/

//#define MANUAL_ICON_SMOOTH // uncomment this if you want manual mode enabled for debugging or whatever (look for ChooseDMI() verb in command tab when running server).

//Redefinitions of the diagonal directions so they can be stored in one var without conflicts
#define N_NORTH       (1<<1)
#define N_SOUTH       (1<<2)
#define N_EAST        (1<<4)
#define N_WEST        (1<<8)
#define N_NORTHEAST   (1<<5)
#define N_NORTHWEST   (1<<9)
#define N_SOUTHEAST   (1<<6)
#define N_SOUTHWEST   (1<<10)

#define SMOOTH_FALSE      0      //not smooth
#define SMOOTH_TRUE       (1<<0) //smooths with exact specified types or just itself
#define SMOOTH_MORE       (1<<1) //smooths with all subtypes of specified types or just itself (this value can replace SMOOTH_TRUE)
#define SMOOTH_DIAGONAL   (1<<2) //if atom should smooth diagonally, this should be present in 'smooth' var
#define SMOOTH_BORDER     (1<<3) //atom will smooth with the borders of the map
#define SMOOTH_QUEUED     (1<<4) //atom is currently queued to smooth.
#define SMOOTH_SMOOTHED   (1<<5) //atom was already smoothed once

#define NULLTURF_BORDER 123456789

#define DEFAULT_UNDERLAY_ICON           'icons/turf/floors.dmi'
#define DEFAULT_UNDERLAY_ICON_STATE     "plating"

#define SMOOTH_ADAPTERS_ICON            'icons/obj/smooth_adapters/adapters.dmi'

/atom/var/smooth = SMOOTH_FALSE
/atom/var/list/canSmoothWith = null // TYPE PATHS I CAN SMOOTH WITH~~~~~ If this is null and atom is smooth, it smooths only with itself
/atom/var/list/smooth_adapters = null // list of adapters we need to request from neighbors, list(/type/ = "state")
/atom/var/icon/smooth_icon_initial // don't touch this, value assigned automatically in the process.
/atom/movable/var/can_be_unanchored = FALSE
/turf/var/list/fixed_underlay = null

/proc/calculate_adjacencies(atom/A)
	if(!A.loc)
		return 0

	var/adjacencies = 0

	var/atom/movable/AM
	if(ismovable(A))
		AM = A
		if(AM.can_be_unanchored && !AM.anchored)
			return 0

	for(var/direction in global.cardinal)
		AM = find_type_in_direction(A, direction)
		if(AM == NULLTURF_BORDER)
			if((A.smooth & SMOOTH_BORDER))
				adjacencies |= 1 << direction
		else if( (AM && !istype(AM)) || (istype(AM) && AM.anchored) )
			adjacencies |= 1 << direction

	if(adjacencies & N_NORTH)
		if(adjacencies & N_WEST)
			AM = find_type_in_direction(A, NORTHWEST)
			if(AM == NULLTURF_BORDER)
				if((A.smooth & SMOOTH_BORDER))
					adjacencies |= N_NORTHWEST
			else if( (AM && !istype(AM)) || (istype(AM) && AM.anchored) )
				adjacencies |= N_NORTHWEST
		if(adjacencies & N_EAST)
			AM = find_type_in_direction(A, NORTHEAST)
			if(AM == NULLTURF_BORDER)
				if((A.smooth & SMOOTH_BORDER))
					adjacencies |= N_NORTHEAST
			else if( (AM && !istype(AM)) || (istype(AM) && AM.anchored) )
				adjacencies |= N_NORTHEAST

	if(adjacencies & N_SOUTH)
		if(adjacencies & N_WEST)
			AM = find_type_in_direction(A, SOUTHWEST)
			if(AM == NULLTURF_BORDER)
				if((A.smooth & SMOOTH_BORDER))
					adjacencies |= N_SOUTHWEST
			else if( (AM && !istype(AM)) || (istype(AM) && AM.anchored) )
				adjacencies |= N_SOUTHWEST
		if(adjacencies & N_EAST)
			AM = find_type_in_direction(A, SOUTHEAST)
			if(AM == NULLTURF_BORDER)
				if((A.smooth & SMOOTH_BORDER))
					adjacencies |= N_SOUTHEAST
			else if( (AM && !istype(AM)) || (istype(AM) && AM.anchored) )
				adjacencies |= N_SOUTHEAST

	return adjacencies

//do not use, use queue_smooth(atom)
/proc/smooth_icon(atom/A)
	if(!A || !(A.smooth || length(A.smooth_adapters)))
		return
	A.smooth &= ~SMOOTH_QUEUED
	if (!A.z)
		return
	if(QDELETED(A))
		return
	if(A.smooth & (SMOOTH_TRUE | SMOOTH_MORE))
		var/adjacencies = calculate_adjacencies(A)

		if(A.smooth & SMOOTH_DIAGONAL)
			A.diagonal_smooth(adjacencies)
		else
			cardinal_smooth(A, adjacencies)

	if(length(A.smooth_adapters))
		A.update_adapters()

	A.smooth |= SMOOTH_SMOOTHED

/atom/proc/diagonal_smooth(adjacencies, read_values = FALSE)
	var/diagonal_states

	switch(adjacencies)
		if(N_NORTH|N_WEST)
			diagonal_states = list("d-se","d-se-0")
		if(N_NORTH|N_EAST)
			diagonal_states = list("d-sw","d-sw-0")
		if(N_SOUTH|N_WEST)
			diagonal_states = list("d-ne","d-ne-0")
		if(N_SOUTH|N_EAST)
			diagonal_states = list("d-nw","d-nw-0")
		if(N_NORTH|N_WEST|N_NORTHWEST)
			diagonal_states = list("d-se","d-se-1")
		if(N_NORTH|N_EAST|N_NORTHEAST)
			diagonal_states = list("d-sw","d-sw-1")
		if(N_SOUTH|N_WEST|N_SOUTHWEST)
			diagonal_states = list("d-ne","d-ne-1")
		if(N_SOUTH|N_EAST|N_SOUTHEAST)
			diagonal_states = list("d-nw","d-nw-1")
		else
			if(!read_values)
				cardinal_smooth(src, adjacencies)
				return // important (removing this will break underlays).
			else
				return cardinal_smooth(null, adjacencies)

	if(diagonal_states)
		if(!read_values)
			smooth_set_icon(adjacencies)
		else
			return diagonal_states

	return adjacencies

//only walls should have a need to handle underlays
/turf/simulated/wall/diagonal_smooth(adjacencies, read_values = FALSE)
	if(read_values)
		return ..()

	adjacencies = reverse_ndir(..())
	if(adjacencies)
		var/mutable_appearance/underlay_appearance = mutable_appearance(layer = TURF_LAYER, plane = FLOOR_PLANE)
		var/list/U = list(underlay_appearance)
		if(fixed_underlay)
			if(fixed_underlay["space"])
				underlay_appearance.icon = 'icons/turf/space.dmi'
				underlay_appearance.icon_state = SPACE_ICON_STATE
				underlay_appearance.plane = PLANE_SPACE
			else
				underlay_appearance.icon = fixed_underlay["icon"]
				underlay_appearance.icon_state = fixed_underlay["icon_state"]
		else
			var/turned_adjacency = turn(adjacencies, 180)
			var/turf/T = get_step(src, turned_adjacency)
			if(!T.get_smooth_underlay_icon(underlay_appearance, src, turned_adjacency))
				T = get_step(src, turn(adjacencies, 135))
				if(!T.get_smooth_underlay_icon(underlay_appearance, src, turned_adjacency))
					T = get_step(src, turn(adjacencies, 225))
			//if all else fails, ask our own turf
			if(!T.get_smooth_underlay_icon(underlay_appearance, src, turned_adjacency) && !get_smooth_underlay_icon(underlay_appearance, src, turned_adjacency))
				underlay_appearance.icon = DEFAULT_UNDERLAY_ICON
				underlay_appearance.icon_state = DEFAULT_UNDERLAY_ICON_STATE
		underlays = U

		// Drop posters which were previously placed on this wall.
		for(var/obj/structure/sign/poster/P in src)
			P.roll_and_drop(src)


/proc/cardinal_smooth(atom/A, adjacencies)
	//NW CORNER
	var/nw = "1-i"
	if((adjacencies & N_NORTH) && (adjacencies & N_WEST))
		if(adjacencies & N_NORTHWEST)
			nw = "1-f"
		else
			nw = "1-nw"
	else
		if(adjacencies & N_NORTH)
			nw = "1-n"
		else if(adjacencies & N_WEST)
			nw = "1-w"

	//NE CORNER
	var/ne = "2-i"
	if((adjacencies & N_NORTH) && (adjacencies & N_EAST))
		if(adjacencies & N_NORTHEAST)
			ne = "2-f"
		else
			ne = "2-ne"
	else
		if(adjacencies & N_NORTH)
			ne = "2-n"
		else if(adjacencies & N_EAST)
			ne = "2-e"

	//SW CORNER
	var/sw = "3-i"
	if((adjacencies & N_SOUTH) && (adjacencies & N_WEST))
		if(adjacencies & N_SOUTHWEST)
			sw = "3-f"
		else
			sw = "3-sw"
	else
		if(adjacencies & N_SOUTH)
			sw = "3-s"
		else if(adjacencies & N_WEST)
			sw = "3-w"

	//SE CORNER
	var/se = "4-i"
	if((adjacencies & N_SOUTH) && (adjacencies & N_EAST))
		if(adjacencies & N_SOUTHEAST)
			se = "4-f"
		else
			se = "4-se"
	else
		if(adjacencies & N_SOUTH)
			se = "4-s"
		else if(adjacencies & N_EAST)
			se = "4-e"

	if(A)
		A.smooth_set_icon(adjacencies)
	else
		return list(nw, ne, sw, se)

/proc/find_type_in_direction(atom/source, direction)
	var/turf/target_turf = get_step(source, direction)
	if(!target_turf)
		return NULLTURF_BORDER

	var/area/target_area = get_area(target_turf)
	var/area/source_area = get_area(source)
	if(source_area.canSmoothWithAreas && !is_type_in_typecache(target_area, source_area.canSmoothWithAreas))
		return null
	if(target_area.canSmoothWithAreas && !is_type_in_typecache(source_area, target_area.canSmoothWithAreas))
		return null

	if(source.canSmoothWith)
		var/atom/A
		if(source.smooth & SMOOTH_MORE)
			for(var/a_type in source.canSmoothWith)
				if( istype(target_turf, a_type) )
					return target_turf
				A = locate(a_type) in target_turf
				if(A)
					return A
			return null

		for(var/a_type in source.canSmoothWith)
			if(a_type == target_turf.type)
				return target_turf
			A = locate(a_type) in target_turf
			if(A && A.type == a_type)
				return A
		return null
	else
		if(isturf(source))
			return source.type == target_turf.type ? target_turf : null
		var/atom/A = locate(source.type) in target_turf
		return A && A.type == source.type ? A : null

//Icon smoothing helpers
/proc/smooth_zlevel(zlevel, now = FALSE)
	var/list/away_turfs = block(locate(1, 1, zlevel), locate(world.maxx, world.maxy, zlevel))
	for(var/V in away_turfs)
		var/turf/T = V
		if(T.smooth)
			if(now)
				smooth_icon(T)
			else
				queue_smooth(T)
		for(var/R in T)
			var/atom/A = R
			if(A.smooth)
				if(now)
					smooth_icon(A)
				else
					queue_smooth(A)

/atom/proc/smooth_set_icon(adjacencies)
#ifdef MANUAL_ICON_SMOOTH
	return
#endif
	if(!smooth_icon_initial)
		smooth_icon_initial = icon
	var/cache_string = "["[type]"]"
	if(!global.baked_smooth_icons[cache_string])
		// has_false_walls is a file PATH flag, yes
		var/icon/I = SliceNDice(icon(smooth_icon_initial), !!findtext("[smooth_icon_initial]", "has_false_walls"))
		global.baked_smooth_icons[cache_string] = I // todo: we can filecache it

	icon = global.baked_smooth_icons[cache_string]
	icon_state = "[adjacencies]"

/atom/proc/regenerate_smooth_icon() // mostly for windows, so we can quickly regenerate same (with same adjacencies) icon with new colors
	if(smooth & SMOOTH_SMOOTHED)
		smooth_set_icon(icon_state) // better to do this through SSicon_smooth but idk how
	else
		queue_smooth(src)

/obj/structure/window/fulltile/smooth_set_icon(adjacencies)
#ifdef MANUAL_ICON_SMOOTH
	return
#endif

	var/cache_string = "["[type]"]"

	if(glass_color)
		cache_string += "[glass_color]"

	if(grilled)
		cache_string += "_grilled"

	if(!global.baked_smooth_icons[cache_string])

		var/icon/blended = new(smooth_icon_windowstill)

		if(grilled)
			var/icon/grille = new(smooth_icon_grille)
			blended.Blend(grille,ICON_OVERLAY)

		var/icon/window = new(smooth_icon_window)
		if(glass_color)
			window.Blend(glass_color, ICON_MULTIPLY)
		blended.Blend(window,ICON_OVERLAY)

		var/icon/I = SliceNDice(blended)
		global.baked_smooth_icons[cache_string] = I

	icon = global.baked_smooth_icons[cache_string]
	icon_state = "[adjacencies]"

/proc/reverse_ndir(ndir)
	switch(ndir)
		if(N_NORTH)
			return NORTH
		if(N_SOUTH)
			return SOUTH
		if(N_WEST)
			return WEST
		if(N_EAST)
			return EAST
		if(N_NORTHWEST)
			return NORTHWEST
		if(N_NORTHEAST)
			return NORTHEAST
		if(N_SOUTHEAST)
			return SOUTHEAST
		if(N_SOUTHWEST)
			return SOUTHWEST
		if(N_NORTH|N_WEST)
			return NORTHWEST
		if(N_NORTH|N_EAST)
			return NORTHEAST
		if(N_SOUTH|N_WEST)
			return SOUTHWEST
		if(N_SOUTH|N_EAST)
			return SOUTHEAST
		if(N_NORTH|N_WEST|N_NORTHWEST)
			return NORTHWEST
		if(N_NORTH|N_EAST|N_NORTHEAST)
			return NORTHEAST
		if(N_SOUTH|N_WEST|N_SOUTHWEST)
			return SOUTHWEST
		if(N_SOUTH|N_EAST|N_SOUTHEAST)
			return SOUTHEAST
		else
			return 0

//SSicon_smooth
/proc/queue_smooth_neighbors(atom/A)
	for(var/V in orange(1,A))
		var/atom/T = V
		if(T.smooth || length(T.smooth_adapters))
			queue_smooth(T)

//SSicon_smooth
/proc/queue_smooth(atom/A)
	if(!(A.smooth || length(A.smooth_adapters)) || A.smooth & SMOOTH_QUEUED)
		return

	SSicon_smooth.smooth_queue += A
	SSicon_smooth.can_fire = TRUE
	A.smooth |= SMOOTH_QUEUED
	A.smooth &= ~SMOOTH_SMOOTHED

/turf/proc/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	underlay_appearance.icon = icon
	underlay_appearance.icon_state = icon_state
	underlay_appearance.dir = adjacency_dir
	return TRUE

/turf/environment/space/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	underlay_appearance.icon = icon
	underlay_appearance.icon_state = icon_state
	underlay_appearance.plane = PLANE_SPACE
	return TRUE

/turf/simulated/wall/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	return FALSE

/turf/simulated/floor/carpet/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	return FALSE

/turf/simulated/mineral/get_smooth_underlay_icon(mutable_appearance/underlay_appearance, turf/asking_turf, adjacency_dir)
	if(basetype)
		underlay_appearance.icon = initial(basetype.icon)
		underlay_appearance.icon_state = initial(basetype.icon_state)
		return TRUE
	return ..()

// adds apecial transition overlays depending on the `smooth_adapters`
/atom/var/list/overlays_adapters
/atom/proc/update_adapters()
	if(!length(smooth_adapters))
		return
	
	if(length(overlays_adapters))
		cut_overlay(overlays_adapters)
	
	overlays_adapters = list()

	for(var/direction in global.cardinal) // yeah, this is another get_step_around for smoothing system. Maybe need to merge it with `calculate_adjacencies` somehow. Anyway, it's not soo bad.
		var/turf/T = get_step(src, direction)
		
		if(!T)
			continue

		var/skip_content_loop = FALSE
		for(var/type in smooth_adapters)
			if(istype(T, type))
				overlays_adapters += image("icon" = SMOOTH_ADAPTERS_ICON, "icon_state" = smooth_adapters[type], dir = get_dir(src, T))
				skip_content_loop = TRUE

		if(skip_content_loop) // remove it in case if we need more that one adapter per dir
			continue

		for(var/atom/A in T)
			for(var/type in smooth_adapters)
				if(istype(A, type))
					overlays_adapters += image("icon" = SMOOTH_ADAPTERS_ICON, "icon_state" = smooth_adapters[type], dir = get_dir(src, A))
					break

	if(length(overlays_adapters))
		add_overlay(overlays_adapters)


/client/proc/generate_fulltile_window_placeholders()
	set name = ".gwp"
	set hidden = TRUE

	//no one should do it on the server, log just in case
	log_admin("[key_name(src)] started generation of the new placeholders for fulltile windows")
	message_admins("[key_name(src)] started generation of the new placeholders for fulltile windows")

	var/list/types = list(
		/obj/structure/window/fulltile,
		/obj/structure/window/fulltile/phoron,
		/obj/structure/window/fulltile/tinted,
		/obj/structure/window/fulltile/polarized,
		/obj/structure/window/fulltile/reinforced,
		/obj/structure/window/fulltile/reinforced/phoron,
		/obj/structure/window/fulltile/reinforced/tinted,
		/obj/structure/window/fulltile/reinforced/polarized,
	)

	var/icon/placeholder = new
	var/obj/structure/window/fulltile/F

	for(var/type in types)
		to_chat(usr, "Generating new placeholder for: [type]")

		F = new type
		F.grilled = FALSE
		F.change_color("#ffffff")

		while(!F.initialized)
			sleep(10)

		F.smooth_set_icon(0)
		var/icon/state = icon(F.icon, "0")

		F.grilled = TRUE
		F.smooth_set_icon(0)
		var/icon/state_grilled = icon(F.icon, "0")

		if(type == /obj/structure/window/fulltile/reinforced/polarized || type == /obj/structure/window/fulltile/polarized) // polarized don't have own blend color so we need to make it different
			for(var/x in 1 to 32)
				for(var/y in 1 to 32)
					if (x == y || x == (32-y+1))
						state.DrawBox("#222222", x, y)
						state_grilled.DrawBox("#222222", x, y)

		to_chat(usr, "New: [bicon(state)]")
		to_chat(usr, "New: [bicon(state_grilled)]")

		// fuck "Runtime in : : bad icon operation"
		// for some inner byond reasons this don't work first time when icon generated
		placeholder.Insert(state, "[initial(F.icon_state)]")
		placeholder.Insert(state_grilled, "gr_[initial(F.icon_state)]")

	fcopy(placeholder, "cache/placeholder.dmi")
	to_chat(usr, "New placeholder saved as \"cache/placeholder.dmi\". Run .gwp second time if icon is empty")


/*
//Example smooth wall
/turf/simulated/wall/smooth
	name = "smooth wall"
	icon = 'icons/turf/smooth_example/smooth_wall_diagonal.dmi'
	icon_state = "smooth"
	smooth = SMOOTH_TRUE|SMOOTH_DIAGONAL|SMOOTH_BORDER
	canSmoothWith = null
*/
