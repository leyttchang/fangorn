extends SceneTree

func _init():
    var packed_scene = load("res://character/enemie/Scout/scout.tscn")
    var scene = packed_scene.instantiate()
    
    var sim = scene.get_node_or_null("Great Sword Run/Skeleton3D/PhysicalBoneSimulator3D")
    if sim != null:
        for child in sim.get_children():
            if child is PhysicalBone3D:
                print("Bone: ", child.name)
                print(" - Joint Type: ", child.joint_type)
                print(" - Angular Damp: ", child.angular_damp_mode, " | Value: ", child.angular_damp)
                print(" - Mass: ", child.mass)
                if child.joint_type == PhysicalBone3D.JOINT_TYPE_CONE:
                    print(" - Swing Span: ", rad_to_deg(child.get("joint_constraints/swing_span")))
                    print(" - Twist Span: ", rad_to_deg(child.get("joint_constraints/twist_span")))
                elif child.joint_type == PhysicalBone3D.JOINT_TYPE_6DOF:
                    print(" - 6DOF Angular Limits...")
    quit()
