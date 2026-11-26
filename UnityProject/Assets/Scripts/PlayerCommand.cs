using UnityEngine;
namespace R280 {
    public struct PlayerCommand {
        public Vector2 Move;
        public Vector2 Look;
        public bool Brake;
    }
    public interface IControllable {
        Transform Anchor { get; }
        void Apply(PlayerCommand command);
        void ResetPose();
    }
    public sealed class LocalInput {
        public Vector2 Move, Look;
        public bool Brake;
        int moveId = -1, lookId = -1;
        Vector2 moveOrigin, lookOrigin;
        public void Poll(bool enabled) {
            Move = Look = Vector2.zero;
            Brake = false;
            if (!enabled) { moveId = lookId = -1; return; }
            float w = Screen.width, h = Screen.height;
            float range = Mathf.Max(50f, h * .15f);
            for (int i=0;i<Input.touchCount;i++) {
                Touch t=Input.GetTouch(i);
                bool ended=t.phase==TouchPhase.Ended || t.phase==TouchPhase.Canceled;
                if (ended) {
                    if(t.fingerId==moveId) moveId=-1;
                    if(t.fingerId==lookId) lookId=-1;
                    continue;
                }
                if(t.phase==TouchPhase.Began) {
                    if(t.position.y<h*.28f && t.position.x>w*.43f && t.position.x<w*.57f) continue;
                    if(t.position.x<w*.5f && t.position.y<h*.65f && moveId<0) {moveId=t.fingerId;moveOrigin=t.position;}
                    else if(t.position.x>=w*.5f && t.position.y<h*.65f && lookId<0) {lookId=t.fingerId;lookOrigin=t.position;}
                }
                if(t.fingerId==moveId) Move=Vector2.ClampMagnitude((t.position-moveOrigin)/range,1);
                if(t.fingerId==lookId) Look=Vector2.ClampMagnitude((t.position-lookOrigin)/range,1);
                if(t.position.y<h*.20f && Mathf.Abs(t.position.x-w*.5f)<w*.065f && t.fingerId!=moveId && t.fingerId!=lookId) Brake=true;
            }
            if(!Application.isMobilePlatform) {
                Move=Vector2.ClampMagnitude(new Vector2((Input.GetKey(KeyCode.D)?1:0)-(Input.GetKey(KeyCode.A)?1:0),(Input.GetKey(KeyCode.W)?1:0)-(Input.GetKey(KeyCode.S)?1:0)),1);
                Look=new Vector2((Input.GetKey(KeyCode.RightArrow)?1:0)-(Input.GetKey(KeyCode.LeftArrow)?1:0),(Input.GetKey(KeyCode.UpArrow)?1:0)-(Input.GetKey(KeyCode.DownArrow)?1:0));
                Brake=Input.GetKey(KeyCode.Space);
            }
        }
    }
}
