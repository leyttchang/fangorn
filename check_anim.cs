using Godot;

public partial class Test : SceneTree
{
    public override void _Initialize()
    {
        var scene = ResourceLoader.Load<PackedScene>("res://character/enemie/dumb_archer/Orc_obj.fbx");
        if (scene != null) {
            var node = scene.Instantiate();
            var animPlayer = node.GetNodeOrNull<AnimationPlayer>("AnimationPlayer");
            if (animPlayer != null) {
                var list = animPlayer.GetAnimationList();
                foreach (var anim in list) {
                    GD.Print("ANIM: " + anim);
                }
            } else {
                GD.Print("NO ANIM PLAYER");
            }
        }
        Quit();
    }
}
