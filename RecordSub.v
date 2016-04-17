(** * RecordSub: Subtyping with Records *)

Require Export MoreStlc.

(* ###################################################### *)
(** * Core Definitions *)

(* ################################### *)
(** *** Syntax *)

Inductive ty : Type :=
  (* proper types *)
  | TTop   : ty
  | TBase  : id -> ty
  | TArrow : ty -> ty -> ty
  (* record types *)
  | TRNil : ty
  | TRCons : id -> ty -> ty -> ty.

Tactic Notation "T_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "TTop" | Case_aux c "TBase" | Case_aux c "TArrow"
  | Case_aux c "TRNil" | Case_aux c "TRCons" ].

Inductive tm : Type :=
  (* proper terms *)
  | tvar : id -> tm
  | tapp : tm -> tm -> tm
  | tabs : id -> ty -> tm -> tm
  | tproj : tm -> id -> tm
  (* record terms *)
  | trnil :  tm
  | trcons : id -> tm -> tm -> tm.

Tactic Notation "t_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "tvar" | Case_aux c "tapp" | Case_aux c "tabs"
  | Case_aux c "tproj" | Case_aux c "trnil" | Case_aux c "trcons" ].

(* ################################### *)
(** *** Well-Formedness *)

Inductive record_ty : ty -> Prop :=
  | RTnil :
  record_ty TRNil
  | RTcons : forall i T1 T2,
  record_ty (TRCons i T1 T2).

Inductive record_tm : tm -> Prop :=
  | rtnil :
  record_tm trnil
  | rtcons : forall i t1 t2,
  record_tm (trcons i t1 t2).

Inductive well_formed_ty : ty -> Prop :=
  | wfTTop :
  well_formed_ty TTop
  | wfTBase : forall i,
  well_formed_ty (TBase i)
  | wfTArrow : forall T1 T2,
  well_formed_ty T1 ->
  well_formed_ty T2 ->
  well_formed_ty (TArrow T1 T2)
  | wfTRNil :
  well_formed_ty TRNil
  | wfTRCons : forall i T1 T2,
  well_formed_ty T1 ->
  well_formed_ty T2 ->
  record_ty T2 ->
  well_formed_ty (TRCons i T1 T2).

Hint Constructors record_ty record_tm well_formed_ty.


(* ################################### *)
(** *** Substitution *)

Fixpoint subst (x:id) (s:tm) (t:tm) : tm :=
  match t with
  | tvar y => if eq_id_dec x y then s else t
  | tabs y T t1 =>  tabs y T (if eq_id_dec x y then t1 else (subst x s t1))
  | tapp t1 t2 => tapp (subst x s t1) (subst x s t2)
  | tproj t1 i => tproj (subst x s t1) i
  | trnil => trnil
  | trcons i t1 tr2 => trcons i (subst x s t1) (subst x s tr2)
  end.

Notation "'[' x ':=' s ']' t" := (subst x s t) (at level 20).

(* ################################### *)
(** *** Reduction *)

Inductive value : tm -> Prop :=
  | v_abs : forall x T t,
      value (tabs x T t)
  | v_rnil : value trnil
  | v_rcons : forall i v vr,
      value v ->
      value vr ->
      value (trcons i v vr).

Hint Constructors value.

Fixpoint Tlookup (i:id) (Tr:ty) : option ty :=
  match Tr with
  | TRCons i' T Tr' => if eq_id_dec i i' then Some T else Tlookup i Tr'
  | _ => None
  end.

Fixpoint tlookup (i:id) (tr:tm) : option tm :=
  match tr with
  | trcons i' t tr' => if eq_id_dec i i' then Some t else tlookup i tr'
  | _ => None
  end.

Reserved Notation "t1 '==>' t2" (at level 40).

Inductive step : tm -> tm -> Prop :=
  | ST_AppAbs : forall x T t12 v2,
   value v2 ->
   (tapp (tabs x T t12) v2) ==> [x:=v2]t12
  | ST_App1 : forall t1 t1' t2,
   t1 ==> t1' ->
   (tapp t1 t2) ==> (tapp t1' t2)
  | ST_App2 : forall v1 t2 t2',
   value v1 ->
   t2 ==> t2' ->
   (tapp v1 t2) ==> (tapp v1  t2')
  | ST_Proj1 : forall tr tr' i,
  tr ==> tr' ->
  (tproj tr i) ==> (tproj tr' i)
  | ST_ProjRcd : forall tr i vi,
  value tr ->
  tlookup i tr = Some vi    ->
       (tproj tr i) ==> vi
  | ST_Rcd_Head : forall i t1 t1' tr2,
  t1 ==> t1' ->
  (trcons i t1 tr2) ==> (trcons i t1' tr2)
  | ST_Rcd_Tail : forall i v1 tr2 tr2',
  value v1 ->
  tr2 ==> tr2' ->
  (trcons i v1 tr2) ==> (trcons i v1 tr2')

where "t1 '==>' t2" := (step t1 t2).

Tactic Notation "step_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "ST_AppAbs" | Case_aux c "ST_App1" | Case_aux c "ST_App2"
  | Case_aux c "ST_Proj1" | Case_aux c "ST_ProjRcd" | Case_aux c "ST_Rcd"
  | Case_aux c "ST_Rcd_Head" | Case_aux c "ST_Rcd_Tail" ].

Hint Constructors step.

(* ###################################################################### *)
(** * Subtyping *)

(** Now we come to the interesting part.  We begin by defining
    the subtyping relation and developing some of its important
    technical properties. *)

(* ################################### *)
(** ** Definition *)

(** The definition of subtyping is essentially just what we
    sketched in the motivating discussion, but we need to add
    well-formedness side conditions to some of the rules. *)

Inductive subtype : ty -> ty -> Prop :=
  (* Subtyping between proper types *)
  | S_Refl : forall T,
    well_formed_ty T ->
    subtype T T
  | S_Trans : forall S U T,
    subtype S U ->
    subtype U T ->
    subtype S T
  | S_Top : forall S,
    well_formed_ty S ->
    subtype S TTop
  | S_Arrow : forall S1 S2 T1 T2,
    subtype T1 S1 ->
    subtype S2 T2 ->
    subtype (TArrow S1 S2) (TArrow T1 T2)
  (* Subtyping between record types *)
  | S_RcdWidth : forall i T1 T2,
    well_formed_ty (TRCons i T1 T2) ->
    subtype (TRCons i T1 T2) TRNil
  | S_RcdDepth : forall i S1 T1 Sr2 Tr2,
    subtype S1 T1 ->
    subtype Sr2 Tr2 ->
    record_ty Sr2 ->
    record_ty Tr2 ->
    subtype (TRCons i S1 Sr2) (TRCons i T1 Tr2)
  | S_RcdPerm : forall i1 i2 T1 T2 Tr3,
    well_formed_ty (TRCons i1 T1 (TRCons i2 T2 Tr3)) ->
    i1 <> i2 ->
    subtype (TRCons i1 T1 (TRCons i2 T2 Tr3))
      (TRCons i2 T2 (TRCons i1 T1 Tr3)).

Hint Constructors subtype.

Tactic Notation "subtype_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "S_Refl" | Case_aux c "S_Trans" | Case_aux c "S_Top"
  | Case_aux c "S_Arrow" | Case_aux c "S_RcdWidth"
  | Case_aux c "S_RcdDepth" | Case_aux c "S_RcdPerm" ].

(* ############################################### *)
(** ** Subtyping Examples and Exercises *)

Module Examples.

Notation x := (Id 0).
Notation y := (Id 1).
Notation z := (Id 2).
Notation j := (Id 3).
Notation k := (Id 4).
Notation i := (Id 5).
Notation A := (TBase (Id 6)).
Notation B := (TBase (Id 7)).
Notation C := (TBase (Id 8)).

Definition TRcd_j  :=
  (TRCons j (TArrow B B) TRNil).     (* {j:B->B} *)
Definition TRcd_kj :=
  TRCons k (TArrow A A) TRcd_j.      (* {k:C->C,j:B->B} *)

Example subtyping_example_0 :
  subtype (TArrow C TRcd_kj)
    (TArrow C TRNil).
(* C->{k:A->A,j:B->B} <: C->{} *)
Proof.
  apply S_Arrow.
    apply S_Refl. auto.
    unfold TRcd_kj, TRcd_j. apply S_RcdWidth; auto.
Qed.

(** The following facts are mostly easy to prove in Coq.  To get
    full benefit from the exercises, make sure you also
    understand how to prove them on paper! *)

(** **** Exercise: 2 stars  *)
Example subtyping_example_1 :
  subtype TRcd_kj TRcd_j.
(* {k:A->A,j:B->B} <: {j:B->B} *)
Proof with eauto.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 1 star  *)
Example subtyping_example_2 :
  subtype (TArrow TTop TRcd_kj)
    (TArrow (TArrow C C) TRcd_j).
(* Top->{k:A->A,j:B->B} <: (C->C)->{j:B->B} *)
Proof with eauto.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 1 star  *)
Example subtyping_example_3 :
  subtype (TArrow TRNil (TRCons j A TRNil))
    (TArrow (TRCons k B TRNil) TRNil).
(* {}->{j:A} <: {k:B}->{} *)
Proof with eauto.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 2 stars  *)
Example subtyping_example_4 :
  subtype (TRCons x A (TRCons y B (TRCons z C TRNil)))
    (TRCons z C (TRCons y B (TRCons x A TRNil))).
(* {x:A,y:B,z:C} <: {z:C,y:B,x:A} *)
Proof with eauto.
  (* FILL IN HERE *) Admitted.
(** [] *)

Definition trcd_kj :=
  (trcons k (tabs z A (tvar z))
     (trcons j (tabs z B (tvar z))
          trnil)).

End Examples.


(* ###################################################################### *)
(** ** Properties of Subtyping *)

(** *** Well-Formedness *)

Lemma subtype__wf : forall S T,
  subtype S T ->
  well_formed_ty T /\ well_formed_ty S.
Proof with eauto.
  intros S T Hsub.
  subtype_cases (induction Hsub) Case;
    intros; try (destruct IHHsub1; destruct IHHsub2)...
  Case "S_RcdPerm".
    split... inversion H. subst. inversion H5...  Qed.

Lemma wf_rcd_lookup : forall i T Ti,
  well_formed_ty T ->
  Tlookup i T = Some Ti ->
  well_formed_ty Ti.
Proof with eauto.
  intros i T.
  T_cases (induction T) Case; intros; try solve by inversion.
  Case "TRCons".
    inversion H. subst. unfold Tlookup in H0.
    destruct (eq_id_dec i i0)...  inversion H0; subst...  Qed.

(** *** Field Lookup *)

(** Our record matching lemmas get a little more complicated in
    the presence of subtyping for two reasons: First, record
    types no longer necessarily describe the exact structure of
    corresponding terms.  Second, reasoning by induction on
    [has_type] derivations becomes harder in general, because
    [has_type] is no longer syntax directed. *)

Lemma rcd_types_match : forall S T i Ti,
  subtype S T ->
  Tlookup i T = Some Ti ->
  exists Si, Tlookup i S = Some Si /\ subtype Si Ti.
Proof with (eauto using wf_rcd_lookup).
  intros S T i Ti Hsub Hget. generalize dependent Ti.
  subtype_cases (induction Hsub) Case; intros Ti Hget;
    try solve by inversion.
  Case "S_Refl".
    exists Ti...
  Case "S_Trans".
    destruct (IHHsub2 Ti) as [Ui Hui]... destruct Hui.
    destruct (IHHsub1 Ui) as [Si Hsi]... destruct Hsi.
    exists Si...
  Case "S_RcdDepth".
    rename i0 into k.
    unfold Tlookup. unfold Tlookup in Hget.
    destruct (eq_id_dec i k)...
    SCase "i = k -- we're looking up the first field".
      inversion Hget. subst. exists S1...
  Case "S_RcdPerm".
    exists Ti. split.
    SCase "lookup".
      unfold Tlookup. unfold Tlookup in Hget.
      destruct (eq_id_dec i i1)...
      SSCase "i = i1 -- we're looking up the first field".
  destruct (eq_id_dec i i2)...
  SSSCase "i = i2 - -contradictory".
    destruct H0.
    subst...
    SCase "subtype".
      inversion H. subst. inversion H5. subst...  Qed.

(** **** Exercise: 3 stars (rcd_types_match_informal)  *)
(** Write a careful informal proof of the [rcd_types_match]
    lemma. *)

(* FILL IN HERE *)
(** [] *)

(** *** Inversion Lemmas *)

(** **** Exercise: 3 stars, optional (sub_inversion_arrow)  *)
Lemma sub_inversion_arrow : forall U V1 V2,
     subtype U (TArrow V1 V2) ->
     exists U1, exists U2,
       (U=(TArrow U1 U2)) /\ (subtype V1 U1) /\ (subtype U2 V2).
Proof with eauto.
  intros U V1 V2 Hs.
  remember (TArrow V1 V2) as V.
  generalize dependent V2. generalize dependent V1.
  (* FILL IN HERE *) Admitted.
(** [] *)

(* ###################################################################### *)
(** * Typing *)

Definition context := id -> (option ty).
Definition empty : context := (fun _ => None).
Definition extend (Gamma : context) (x:id) (T : ty) :=
  fun x' => if eq_id_dec x x' then Some T else Gamma x'.

Reserved Notation "Gamma '|-' t '\in' T" (at level 40).

Inductive has_type : context -> tm -> ty -> Prop :=
  | T_Var : forall Gamma x T,
      Gamma x = Some T ->
      well_formed_ty T ->
      has_type Gamma (tvar x) T
  | T_Abs : forall Gamma x T11 T12 t12,
      well_formed_ty T11 ->
      has_type (extend Gamma x T11) t12 T12 ->
      has_type Gamma (tabs x T11 t12) (TArrow T11 T12)
  | T_App : forall T1 T2 Gamma t1 t2,
      has_type Gamma t1 (TArrow T1 T2) ->
      has_type Gamma t2 T1 ->
      has_type Gamma (tapp t1 t2) T2
  | T_Proj : forall Gamma i t T Ti,
      has_type Gamma t T ->
      Tlookup i T = Some Ti ->
      has_type Gamma (tproj t i) Ti
  (* Subsumption *)
  | T_Sub : forall Gamma t S T,
      has_type Gamma t S ->
      subtype S T ->
      has_type Gamma t T
  (* Rules for record terms *)
  | T_RNil : forall Gamma,
      has_type Gamma trnil TRNil
  | T_RCons : forall Gamma i t T tr Tr,
      has_type Gamma t T ->
      has_type Gamma tr Tr ->
      record_ty Tr ->
      record_tm tr ->
      has_type Gamma (trcons i t tr) (TRCons i T Tr)

where "Gamma '|-' t '\in' T" := (has_type Gamma t T).

Hint Constructors has_type.

Tactic Notation "has_type_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "T_Var" | Case_aux c "T_Abs" | Case_aux c "T_App"
  | Case_aux c "T_Proj" | Case_aux c "T_Sub"
  | Case_aux c "T_RNil" | Case_aux c "T_RCons" ].

(* ############################################### *)
(** ** Typing Examples *)

Module Examples2.
Import Examples.

(** **** Exercise: 1 star  *)
Example typing_example_0 :
  has_type empty
     (trcons k (tabs z A (tvar z))
         (trcons j (tabs z B (tvar z))
             trnil))
     TRcd_kj.
(* empty |- {k=(\z:A.z), j=(\z:B.z)} : {k:A->A,j:B->B} *)
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 2 stars  *)
Example typing_example_1 :
  has_type empty
     (tapp (tabs x TRcd_j (tproj (tvar x) j))
       (trcd_kj))
     (TArrow B B).
(* empty |- (\x:{k:A->A,j:B->B}. x.j) {k=(\z:A.z), j=(\z:B.z)} : B->B *)
Proof with eauto.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 2 stars, optional  *)
Example typing_example_2 :
  has_type empty
     (tapp (tabs z (TArrow (TArrow C C) TRcd_j)
         (tproj (tapp (tvar z)
              (tabs x C (tvar x)))
            j))
       (tabs z (TArrow C C) trcd_kj))
     (TArrow B B).
(* empty |- (\z:(C->C)->{j:B->B}. (z (\x:C.x)).j)
        (\z:C->C. {k=(\z:A.z), j=(\z:B.z)})
     : B->B *)
Proof with eauto.
  (* FILL IN HERE *) Admitted.
(** [] *)

End Examples2.

(* ###################################################################### *)
(** ** Properties of Typing *)

(** *** Well-Formedness *)

Lemma has_type__wf : forall Gamma t T,
  has_type Gamma t T -> well_formed_ty T.
Proof with eauto.
  intros Gamma t T Htyp.
  has_type_cases (induction Htyp) Case...
  Case "T_App".
    inversion IHHtyp1...
  Case "T_Proj".
    eapply wf_rcd_lookup...
  Case "T_Sub".
    apply subtype__wf in H.
    destruct H...
Qed.

Lemma step_preserves_record_tm : forall tr tr',
  record_tm tr ->
  tr ==> tr' ->
  record_tm tr'.
Proof.
  intros tr tr' Hrt Hstp.
  inversion Hrt; subst; inversion Hstp; subst; eauto.
Qed.

(** *** Field Lookup *)

Lemma lookup_field_in_value : forall v T i Ti,
  value v ->
  has_type empty v T ->
  Tlookup i T = Some Ti ->
  exists vi, tlookup i v = Some vi /\ has_type empty vi Ti.
Proof with eauto.
  remember empty as Gamma.
  intros t T i Ti Hval Htyp. revert Ti HeqGamma Hval.
  has_type_cases (induction Htyp) Case; intros; subst; try solve by inversion.
  Case "T_Sub".
    apply (rcd_types_match S) in H0... destruct H0 as [Si [HgetSi Hsub]].
    destruct (IHHtyp Si) as [vi [Hget Htyvi]]...
  Case "T_RCons".
    simpl in H0. simpl. simpl in H1.
    destruct (eq_id_dec i i0).
    SCase "i is first".
      inversion H1. subst. exists t...
    SCase "i in tail".
      destruct (IHHtyp2 Ti) as [vi [get Htyvi]]...
      inversion Hval...  Qed.

(* ########################################## *)
(** *** Progress *)

(** **** Exercise: 3 stars (canonical_forms_of_arrow_types)  *)
Lemma canonical_forms_of_arrow_types : forall Gamma s T1 T2,
     has_type Gamma s (TArrow T1 T2) ->
     value s ->
     exists x, exists S1, exists s2,
  s = tabs x S1 s2.
Proof with eauto.
  (* FILL IN HERE *) Admitted.
(** [] *)

Theorem progress : forall t T,
     has_type empty t T ->
     value t \/ exists t', t ==> t'.
Proof with eauto.
  intros t T Ht.
  remember empty as Gamma.
  revert HeqGamma.
  has_type_cases (induction Ht) Case;
    intros HeqGamma; subst...
  Case "T_Var".
    inversion H.
  Case "T_App".
    right.
    destruct IHHt1; subst...
    SCase "t1 is a value".
      destruct IHHt2; subst...
      SSCase "t2 is a value".
  destruct (canonical_forms_of_arrow_types empty t1 T1 T2)
    as [x [S1 [t12 Heqt1]]]...
  subst. exists ([x:=t2]t12)...
      SSCase "t2 steps".
  destruct H0 as [t2' Hstp]. exists (tapp t1 t2')...
    SCase "t1 steps".
      destruct H as [t1' Hstp]. exists (tapp t1' t2)...
  Case "T_Proj".
    right. destruct IHHt...
    SCase "rcd is value".
      destruct (lookup_field_in_value t T i Ti) as [t' [Hget Ht']]...
    SCase "rcd_steps".
      destruct H0 as [t' Hstp]. exists (tproj t' i)...
  Case "T_RCons".
    destruct IHHt1...
    SCase "head is a value".
      destruct IHHt2...
      SSCase "tail steps".
  right. destruct H2 as [tr' Hstp].
  exists (trcons i t tr')...
    SCase "head steps".
      right. destruct H1 as [t' Hstp].
      exists (trcons i t' tr)...  Qed.

(** Informal proof of progress:

    Theorem : For any term [t] and type [T], if [empty |- t : T]
      then [t] is a value or [t ==> t'] for some term [t'].

    Proof : Let [t] and [T] be given such that [empty |- t : T].  We go
      by induction on the typing derivation.  Cases [T_Abs] and
      [T_RNil] are immediate because abstractions and [{}] are always
      values.  Case [T_Var] is vacuous because variables cannot be
      typed in the empty context.

      - If the last step in the typing derivation is by [T_App], then
  there are terms [t1] [t2] and types [T1] [T2] such that
  [t = t1 t2], [T = T2], [empty |- t1 : T1 -> T2] and
  [empty |- t2 : T1].

  The induction hypotheses for these typing derivations yield
  that [t1] is a value or steps, and that [t2] is a value or
  steps.  We consider each case:

  - Suppose [t1 ==> t1'] for some term [t1'].  Then
    [t1 t2 ==> t1' t2] by [ST_App1].

  - Otherwise [t1] is a value.

    - Suppose [t2 ==> t2'] for some term [t2'].  Then
      [t1 t2 ==> t1 t2'] by rule [ST_App2] because [t1] is a value.

    - Otherwise, [t2] is a value.  By lemma
      [canonical_forms_for_arrow_types], [t1 = \x:S1.s2] for some
      [x], [S1], and [s2].  And [(\x:S1.s2) t2 ==> [x:=t2]s2] by
      [ST_AppAbs], since [t2] is a value.

      - If the last step of the derivation is by [T_Proj], then there
  is a term [tr], type [Tr] and label [i] such that [t = tr.i],
  [empty |- tr : Tr], and [Tlookup i Tr = Some T].

  The IH for the typing subderivation gives us that either [tr]
  is a value or it steps.  If [tr ==> tr'] for some term [tr'],
  then [tr.i ==> tr'.i] by rule [ST_Proj1].

  Otherwise, [tr] is a value.  In this case, lemma
  [lookup_field_in_value] yields that there is a term [ti] such
  that [tlookup i tr = Some ti].  It follows that [tr.i ==> ti]
  by rule [ST_ProjRcd].

      - If the final step of the derivation is by [T_Sub], then there
  is a type [S] such that [S <: T] and [empty |- t : S].  The
  desired result is exactly the induction hypothesis for the
  typing subderivation.

      - If the final step of the derivation is by [T_RCons], then there
  exist some terms [t1] [tr], types [T1 Tr] and a label [t] such
  that [t = {i=t1, tr}], [T = {i:T1, Tr}], [record_tm tr],
  [record_tm Tr], [empty |- t1 : T1] and [empty |- tr : Tr].

  The induction hypotheses for these typing derivations yield
  that [t1] is a value or steps, and that [tr] is a value or
  steps.  We consider each case:

  - Suppose [t1 ==> t1'] for some term [t1'].  Then
    [{i=t1, tr} ==> {i=t1', tr}] by rule [ST_Rcd_Head].

  - Otherwise [t1] is a value.

    - Suppose [tr ==> tr'] for some term [tr'].  Then
      [{i=t1, tr} ==> {i=t1, tr'}] by rule [ST_Rcd_Tail],
      since [t1] is a value.

    - Otherwise, [tr] is also a value.  So, [{i=t1, tr}] is a
      value by [v_rcons]. *)

(* ########################################## *)
(** *** Inversion Lemmas *)

Lemma typing_inversion_var : forall Gamma x T,
  has_type Gamma (tvar x) T ->
  exists S,
    Gamma x = Some S /\ subtype S T.
Proof with eauto.
  intros Gamma x T Hty.
  remember (tvar x) as t.
  has_type_cases (induction Hty) Case; intros;
    inversion Heqt; subst; try solve by inversion.
  Case "T_Var".
    exists T...
  Case "T_Sub".
    destruct IHHty as [U [Hctx HsubU]]... Qed.

Lemma typing_inversion_app : forall Gamma t1 t2 T2,
  has_type Gamma (tapp t1 t2) T2 ->
  exists T1,
    has_type Gamma t1 (TArrow T1 T2) /\
    has_type Gamma t2 T1.
Proof with eauto.
  intros Gamma t1 t2 T2 Hty.
  remember (tapp t1 t2) as t.
  has_type_cases (induction Hty) Case; intros;
    inversion Heqt; subst; try solve by inversion.
  Case "T_App".
    exists T1...
  Case "T_Sub".
    destruct IHHty as [U1 [Hty1 Hty2]]...
    assert (Hwf := has_type__wf _ _ _ Hty2).
    exists U1...  Qed.

Lemma typing_inversion_abs : forall Gamma x S1 t2 T,
     has_type Gamma (tabs x S1 t2) T ->
     (exists S2, subtype (TArrow S1 S2) T
        /\ has_type (extend Gamma x S1) t2 S2).
Proof with eauto.
  intros Gamma x S1 t2 T H.
  remember (tabs x S1 t2) as t.
  has_type_cases (induction H) Case;
    inversion Heqt; subst; intros; try solve by inversion.
  Case "T_Abs".
    assert (Hwf := has_type__wf _ _ _ H0).
    exists T12...
  Case "T_Sub".
    destruct IHhas_type as [S2 [Hsub Hty]]...
    Qed.

Lemma typing_inversion_proj : forall Gamma i t1 Ti,
  has_type Gamma (tproj t1 i) Ti ->
  exists T, exists Si,
    Tlookup i T = Some Si /\ subtype Si Ti /\ has_type Gamma t1 T.
Proof with eauto.
  intros Gamma i t1 Ti H.
  remember (tproj t1 i) as t.
  has_type_cases (induction H) Case;
    inversion Heqt; subst; intros; try solve by inversion.
  Case "T_Proj".
    assert (well_formed_ty Ti) as Hwf.
      SCase "pf of assertion".
  apply (wf_rcd_lookup i T Ti)...
  apply has_type__wf in H...
    exists T. exists Ti...
  Case "T_Sub".
    destruct IHhas_type as [U [Ui [Hget [Hsub Hty]]]]...
    exists U. exists Ui...  Qed.

Lemma typing_inversion_rcons : forall Gamma i ti tr T,
  has_type Gamma (trcons i ti tr) T ->
  exists Si, exists Sr,
    subtype (TRCons i Si Sr) T /\ has_type Gamma ti Si /\
    record_tm tr /\ has_type Gamma tr Sr.
Proof with eauto.
  intros Gamma i ti tr T Hty.
  remember (trcons i ti tr) as t.
  has_type_cases (induction Hty) Case;
    inversion Heqt; subst...
  Case "T_Sub".
    apply IHHty in H0.
    destruct H0 as [Ri [Rr [HsubRS [HtypRi HtypRr]]]].
    exists Ri. exists Rr...
  Case "T_RCons".
    assert (well_formed_ty (TRCons i T Tr)) as Hwf.
      SCase "pf of assertion".
  apply has_type__wf in Hty1.
  apply has_type__wf in Hty2...
    exists T. exists Tr...  Qed.

Lemma abs_arrow : forall x S1 s2 T1 T2,
  has_type empty (tabs x S1 s2) (TArrow T1 T2) ->
     subtype T1 S1
  /\ has_type (extend empty x S1) s2 T2.
Proof with eauto.
  intros x S1 s2 T1 T2 Hty.
  apply typing_inversion_abs in Hty.
  destruct Hty as [S2 [Hsub Hty]].
  apply sub_inversion_arrow in Hsub.
  destruct Hsub as [U1 [U2 [Heq [Hsub1 Hsub2]]]].
  inversion Heq; subst...  Qed.

(* ########################################## *)
(** *** Context Invariance *)

Inductive appears_free_in : id -> tm -> Prop :=
  | afi_var : forall x,
      appears_free_in x (tvar x)
  | afi_app1 : forall x t1 t2,
      appears_free_in x t1 -> appears_free_in x (tapp t1 t2)
  | afi_app2 : forall x t1 t2,
      appears_free_in x t2 -> appears_free_in x (tapp t1 t2)
  | afi_abs : forall x y T11 t12,
  y <> x  ->
  appears_free_in x t12 ->
  appears_free_in x (tabs y T11 t12)
  | afi_proj : forall x t i,
      appears_free_in x t ->
      appears_free_in x (tproj t i)
  | afi_rhead : forall x i t tr,
      appears_free_in x t ->
      appears_free_in x (trcons i t tr)
  | afi_rtail : forall x i t tr,
      appears_free_in x tr ->
      appears_free_in x (trcons i t tr).

Hint Constructors appears_free_in.

Lemma context_invariance : forall Gamma Gamma' t S,
     has_type Gamma t S  ->
     (forall x, appears_free_in x t -> Gamma x = Gamma' x)  ->
     has_type Gamma' t S.
Proof with eauto.
  intros. generalize dependent Gamma'.
  has_type_cases (induction H) Case;
    intros Gamma' Heqv...
  Case "T_Var".
    apply T_Var... rewrite <- Heqv...
  Case "T_Abs".
    apply T_Abs... apply IHhas_type. intros x0 Hafi.
    unfold extend. destruct (eq_id_dec x x0)...
  Case "T_App".
    apply T_App with T1...
  Case "T_RCons".
    apply T_RCons...  Qed.

Lemma free_in_context : forall x t T Gamma,
   appears_free_in x t ->
   has_type Gamma t T ->
   exists T', Gamma x = Some T'.
Proof with eauto.
  intros x t T Gamma Hafi Htyp.
  has_type_cases (induction Htyp) Case; subst; inversion Hafi; subst...
  Case "T_Abs".
    destruct (IHHtyp H5) as [T Hctx]. exists T.
    unfold extend in Hctx. rewrite neq_id in Hctx...  Qed.

(* ########################################## *)
(** *** Preservation *)

Lemma substitution_preserves_typing : forall Gamma x U v t S,
     has_type (extend Gamma x U) t S  ->
     has_type empty v U   ->
     has_type Gamma ([x:=v]t) S.
Proof with eauto.
  intros Gamma x U v t S Htypt Htypv.
  generalize dependent S. generalize dependent Gamma.
  t_cases (induction t) Case; intros; simpl.
  Case "tvar".
    rename i into y.
    destruct (typing_inversion_var _ _ _ Htypt) as [T [Hctx Hsub]].
    unfold extend in Hctx.
    destruct (eq_id_dec x y)...
    SCase "x=y".
      subst.
      inversion Hctx; subst. clear Hctx.
      apply context_invariance with empty...
      intros x Hcontra.
      destruct (free_in_context _ _ S empty Hcontra) as [T' HT']...
      inversion HT'.
    SCase "x<>y".
      destruct (subtype__wf _ _ Hsub)...
  Case "tapp".
    destruct (typing_inversion_app _ _ _ _ Htypt) as [T1 [Htypt1 Htypt2]].
    eapply T_App...
  Case "tabs".
    rename i into y. rename t into T1.
    destruct (typing_inversion_abs _ _ _ _ _ Htypt)
      as [T2 [Hsub Htypt2]].
    destruct (subtype__wf _ _ Hsub) as [Hwf1 Hwf2].
    inversion Hwf2. subst.
    apply T_Sub with (TArrow T1 T2)... apply T_Abs...
    destruct (eq_id_dec x y).
    SCase "x=y".
      eapply context_invariance...
      subst.
      intros x Hafi. unfold extend.
      destruct (eq_id_dec y x)...
    SCase "x<>y".
      apply IHt. eapply context_invariance...
      intros z Hafi. unfold extend.
      destruct (eq_id_dec y z)...
      subst.  rewrite neq_id...
  Case "tproj".
    destruct (typing_inversion_proj _ _ _ _ Htypt)
      as [T [Ti [Hget [Hsub Htypt1]]]]...
  Case "trnil".
    eapply context_invariance...
    intros y Hcontra. inversion Hcontra.
  Case "trcons".
    destruct (typing_inversion_rcons _ _ _ _ _ Htypt) as
      [Ti [Tr [Hsub [HtypTi [Hrcdt2 HtypTr]]]]].
    apply T_Sub with (TRCons i Ti Tr)...
    apply T_RCons...
    SCase "record_ty Tr".
      apply subtype__wf in Hsub. destruct Hsub. inversion H0...
    SCase "record_tm ([x:=v]t2)".
      inversion Hrcdt2; subst; simpl...  Qed.

Theorem preservation : forall t t' T,
     has_type empty t T  ->
     t ==> t'  ->
     has_type empty t' T.
Proof with eauto.
  intros t t' T HT.
  remember empty as Gamma. generalize dependent HeqGamma.
  generalize dependent t'.
  has_type_cases (induction HT) Case;
    intros t' HeqGamma HE; subst; inversion HE; subst...
  Case "T_App".
    inversion HE; subst...
    SCase "ST_AppAbs".
      destruct (abs_arrow _ _ _ _ _ HT1) as [HA1 HA2].
      apply substitution_preserves_typing with T...
  Case "T_Proj".
    destruct (lookup_field_in_value _ _ _ _ H2 HT H)
      as [vi [Hget Hty]].
    rewrite H4 in Hget. inversion Hget. subst...
  Case "T_RCons".
    eauto using step_preserves_record_tm.  Qed.

(** Informal proof of [preservation]:

    Theorem: If [t], [t'] are terms and [T] is a type such that
     [empty |- t : T] and [t ==> t'], then [empty |- t' : T].

    Proof: Let [t] and [T] be given such that [empty |- t : T].  We go
     by induction on the structure of this typing derivation, leaving
     [t'] general.  Cases [T_Abs] and [T_RNil] are vacuous because
     abstractions and {} don't step.  Case [T_Var] is vacuous as well,
     since the context is empty.

     - If the final step of the derivation is by [T_App], then there
       are terms [t1] [t2] and types [T1] [T2] such that [t = t1 t2],
       [T = T2], [empty |- t1 : T1 -> T2] and [empty |- t2 : T1].

       By inspection of the definition of the step relation, there are
       three ways [t1 t2] can step.  Cases [ST_App1] and [ST_App2]
       follow immediately by the induction hypotheses for the typing
       subderivations and a use of [T_App].

       Suppose instead [t1 t2] steps by [ST_AppAbs].  Then
       [t1 = \x:S.t12] for some type [S] and term [t12], and
       [t' = [x:=t2]t12].

       By Lemma [abs_arrow], we have [T1 <: S] and [x:S1 |- s2 : T2].
       It then follows by lemma [substitution_preserves_typing] that
       [empty |- [x:=t2] t12 : T2] as desired.

     - If the final step of the derivation is by [T_Proj], then there
       is a term [tr], type [Tr] and label [i] such that [t = tr.i],
       [empty |- tr : Tr], and [Tlookup i Tr = Some T].

       The IH for the typing derivation gives us that, for any term
       [tr'], if [tr ==> tr'] then [empty |- tr' Tr].  Inspection of
       the definition of the step relation reveals that there are two
       ways a projection can step.  Case [ST_Proj1] follows
       immediately by the IH.

       Instead suppose [tr.i] steps by [ST_ProjRcd].  Then [tr] is a
       value and there is some term [vi] such that
       [tlookup i tr = Some vi] and [t' = vi].  But by lemma
       [lookup_field_in_value], [empty |- vi : Ti] as desired.

     - If the final step of the derivation is by [T_Sub], then there
       is a type [S] such that [S <: T] and [empty |- t : S].  The
       result is immediate by the induction hypothesis for the typing
       subderivation and an application of [T_Sub].

     - If the final step of the derivation is by [T_RCons], then there
       exist some terms [t1] [tr], types [T1 Tr] and a label [t] such
       that [t = {i=t1, tr}], [T = {i:T1, Tr}], [record_tm tr],
       [record_tm Tr], [empty |- t1 : T1] and [empty |- tr : Tr].

       By the definition of the step relation, [t] must have stepped
       by [ST_Rcd_Head] or [ST_Rcd_Tail].  In the first case, the
       result follows by the IH for [t1]'s typing derivation and
       [T_RCons].  In the second case, the result follows by the IH
       for [tr]'s typing derivation, [T_RCons], and a use of the
       [step_preserves_record_tm] lemma. *)

(* ###################################################### *)
(** ** Exercises on Typing *)

(** **** Exercise: 2 stars, optional (variations)  *)
(** Each part of this problem suggests a different way of
    changing the definition of the STLC with records and
    subtyping.  (These changes are not cumulative: each part
    starts from the original language.)  In each part, list which
    properties (Progress, Preservation, both, or neither) become
    false.  If a property becomes false, give a counterexample.
    - Suppose we add the following typing rule:
          Gamma |- t : S1->S2
        S1 <: T1      T1 <: S1     S2 <: T2
        -----------------------------------              (T_Funny1)
          Gamma |- t : T1->T2

    - Suppose we add the following reduction rule:
           ------------------                     (ST_Funny21)
           {} ==> (\x:Top. x)

    - Suppose we add the following subtyping rule:
             --------------                        (S_Funny3)
             {} <: Top->Top

    - Suppose we add the following subtyping rule:
             --------------                        (S_Funny4)
             Top->Top <: {}

    - Suppose we add the following evaluation rule:
           -----------------                      (ST_Funny5)
           ({} t) ==> (t {})

    - Suppose we add the same evaluation rule *and* a new typing rule:
           -----------------                      (ST_Funny5)
           ({} t) ==> (t {})

         ----------------------                    (T_Funny6)
         empty |- {} : Top->Top

    - Suppose we *change* the arrow subtyping rule to:
        S1 <: T1       S2 <: T2
        -----------------------                    (S_Arrow')
             S1->S2 <: T1->T2

(** [] *)


*)

(** $Date: 2014-12-31 11:17:56 -0500 (Wed, 31 Dec 2014) $ *)
