extends SceneTree

func _init():
    var packed_scene = load("res://character/enemie/Scout/scout.tscn")
    var scene = packed_scene.instantiate()
    
    var sim = scene.get_node_or_null("Great Sword Run/Skeleton3D/PhysicalBoneSimulator3D")
    if sim != null:
        for child in sim.get_children():
            if child is PhysicalBone3D:
                # Appliquer le Damping
                child.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
                child.angular_damp = 10.0
                child.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
                child.linear_damp = 2.0
                
                # Rigidifier fortement Spine et Hips
                if "Spine" in child.name or "Hips" in child.name or "Neck" in child.name:
                    if child.joint_type == PhysicalBone3D.JOINT_TYPE_CONE:
                        child.set("joint_constraints/swing_span", deg_to_rad(5.0))
                        child.set("joint_constraints/twist_span", deg_to_rad(5.0))
                # Rigidifier un peu les membres (genoux, coudes)
                elif "Leg" in child.name or "Arm" in child.name:
                    if child.joint_type == PhysicalBone3D.JOINT_TYPE_CONE:
                        child.set("joint_constraints/swing_span", deg_to_rad(45.0))
                        child.set("joint_constraints/twist_span", deg_to_rad(10.0))

    var new_packed = PackedScene.new()
    new_packed.pack(scene)
    ResourceSaver.save(new_packed, "res://character/enemie/Scout/scout.tscn")
    print("[RAGDOLL FIX] Squelette mis a jour avec succes et sauvegarde !")
    quit()
