using UnityEngine;
namespace Roadline {
public sealed class MobileInput : MonoBehaviour {
 public Vector2 Move {get;private set;} public Vector2 Look {get;private set;}
 public Vector2 Stick {get;private set;} public bool Brake {get;private set;}
 public float Lift {get;private set;} public float Sensitivity=1;
 int moveId=-1,lookId=-1; Vector2 anchor; public Vector2 Anchor=>anchor;
 public bool TouchActive=>moveId!=-1;
 public bool Active=true;
 public float Radius=>Mathf.Min(Screen.width,Screen.height)*.14f;
 public void ResetInput(){moveId=lookId=-1;Move=Look=Stick=Vector2.zero;Brake=false;Lift=0;}
 void Update(){
  if(!Active){ResetInput();return;}
  Look=Vector2.zero;Brake=false;Lift=0;
  if(Input.touchCount>0){
   bool hasMove=false,hasLook=false;
   foreach(Touch t in Input.touches){
    Vector2 p=t.position;bool ended=t.phase==TouchPhase.Ended||t.phase==TouchPhase.Canceled;
    if(t.phase==TouchPhase.Began && p.y<Screen.height*.62f){
     if(p.x<Screen.width*.42f&&moveId==-1){moveId=t.fingerId;anchor=p;}
     else if(p.x>Screen.width*.42f&&p.x<Screen.width*.78f&&lookId==-1)lookId=t.fingerId;
    }
    if(t.fingerId==moveId){hasMove=!ended;if(!ended)Stick=Vector2.ClampMagnitude((p-anchor)/Radius,1);}
    if(t.fingerId==lookId){hasLook=!ended;if(!ended)Look=t.deltaPosition*Sensitivity;}
    if(!ended&&p.x>Screen.width*.82f&&p.y<Screen.height*.58f){if(p.y<Screen.height*.24f){Brake=true;Lift=-1;}else Lift=1;}
   }
   if(!hasMove){moveId=-1;Stick=Vector2.zero;} if(!hasLook)lookId=-1;Move=Stick;
  } else {
   moveId=lookId=-1;Stick=Vector2.zero;
   Move=new Vector2((Input.GetKey(KeyCode.D)?1:0)-(Input.GetKey(KeyCode.A)?1:0),(Input.GetKey(KeyCode.W)?1:0)-(Input.GetKey(KeyCode.S)?1:0));
   if(Input.GetMouseButton(1))Look=new Vector2(Input.GetAxisRaw("Mouse X"),Input.GetAxisRaw("Mouse Y"))*12*Sensitivity;
   Brake=Input.GetKey(KeyCode.Space);Lift=(Input.GetKey(KeyCode.E)?1:0)-(Input.GetKey(KeyCode.Q)?1:0);
  }
 }
}
}
