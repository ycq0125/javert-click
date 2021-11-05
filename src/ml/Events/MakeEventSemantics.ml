open CCommon
open SCommon
open Literal 
open Events

module L = Logging

module M 
  (Val           : Val.M) 
  (Error         : Error.M with type vt = Val.t and type event_t = string)
  (Interpreter   : Interpreter.M with type vt = Val.t and type err_t = Error.t) 
  (Scheduler     : EventScheduler.M)
    : EventSemantics.M with type vt = Val.t and type await_conf_t = Interpreter.cconf_t and type conf_info_t = Interpreter.conf_info_t and type interp_result_t = Interpreter.result_t = struct

  type vt = Val.t 

  type event_t = (vt) Events.t

  type err_t = Error.t 

  type fid_t = Interpreter.fid_t

  type await_conf_t = Interpreter.cconf_t

  type interp_result_t = Interpreter.result_t
  
  type conf_info_t = Interpreter.store_t * Interpreter.call_stack_t * int * int * int

  type message_label_t = (vt) MPInterceptor.t

  type event_label_t = (Interpreter.cconf_t, Interpreter.conf_info_t, vt, message_label_t) EventInterceptor.t

  type event_handlers_t = (event_t, (fid_t * vt list) list) SymbMap.t 

  type hq_element = (Interpreter.econf_t, vt, conf_info_t) Scheduler.scheduled_unit_t

  type handler_queue_t = hq_element list 

  (* JSIL conf, event-handlers map, handlers queue and number of events dispatched *)
  type state_t = Interpreter.econf_t * event_handlers_t * handler_queue_t * int

  type result_t = Interpreter.result_t * event_handlers_t * handler_queue_t

  exception Event_not_found of string;;

  let lines_executed : (string * int, unit) Hashtbl.t = Hashtbl.create 1

  let add_event_handler (state: state_t) (event : event_t) (fid : fid_t) (args : vt list) : state_t list =  
    let ((conf, prog), ehs, hq, n) = state in
    let rets = 
      List.map 
        (fun (ehs', f) -> 
          Option.map 
            (fun conf' -> ((conf', prog), ehs', hq, n))
            (Interpreter.assume conf [f]))
        (SymbMap.replace ehs event [(fid,args)] (Events.is_concrete Val.to_literal) (Events.to_expr Val.to_expr)
          (fun handlers_old handlers_new -> 
            let fids, _ = List.split handlers_old in
            let handlers_new = List.filter (fun (fid, _) -> not (List.mem fid fids)) handlers_new in
            handlers_old @ handlers_new)) in 
        CCommon.get_list_somes rets 


  let remove_event_handler (state: state_t) (event : event_t) (fid : fid_t) : state_t list = 
    let ((conf, prog), ehs, hq, n) = state in
    let rets = 
      List.map 
        (fun (ehs', f) -> 
          Option.map 
            (fun conf' -> ((conf', prog), ehs', hq, n))
            (Interpreter.assume conf [f]))
        (SymbMap.replace ehs event [(fid, [])] (Events.is_concrete Val.to_literal) (Events.to_expr Val.to_expr)
          (fun handlers handlers_rem -> 
              let fids, _ = List.split handlers_rem in
              List.filter (fun (fid, _) -> not (List.mem fid fids)) handlers)) in 
        CCommon.get_list_somes rets

  let rec only_timing_events_left (hq: handler_queue_t) : bool =
    match hq with
    | [] -> true
    | (x::xs) -> (
      match x with
      | Handler (_, _, event, _) -> (Events.is_timing_event event) && only_timing_events_left xs;
      | CondConf _ -> only_timing_events_left xs
      | Conf _ -> false 
    )
  
  let final_with_timing_events (state: state_t) : bool =
    let (conf, _, hq, _) = state in
    if (Interpreter.final conf) then (
      match hq with
      | [] -> true
      | hq -> only_timing_events_left hq
    ) else ( false )

  let final (state : state_t) : bool =
    let (conf, _, hq, _) = state in
    if (Interpreter.final conf) then (
      match hq with
      | [] -> true
      | _ -> false
    ) else ( false )

  let assume (state: state_t) (f: Formula.t) : state_t option =
    let (conf, prog), ehs, hq, n = state in
    Option.map (fun conf' -> (conf', prog), ehs, hq, n) (Interpreter.assume conf [f])

  let eval_expr (estate: state_t) (expr: Expr.t) : vt = 
    let ((cconf,_), _, _, _) = estate in
    Interpreter.eval_expr cconf expr

  let rec create_event_id (hq: handler_queue_t) : int =
    Random.self_init ();
    let eid = Random.int 1000 in
    let present = List.fold_left 
      (fun acc su -> match su with
        | Scheduler.Handler (_, _, TimingEvent (id, _), _) -> id = eid
        | _ -> acc) false hq in 
    if (present) then (create_event_id hq) else eid

  (** Continuation **)
  let exec_handler (state : state_t) : state_t list =
    let (conf : Interpreter.econf_t), ehs, hq, n = state in
    Interpreter.check_handler_continue conf; 
    (** Exec Handler *)
      match Scheduler.schedule hq n with
      (** No more handlers to execute *)
      | None, _ -> [] 
      (** Execute next handler *)
      | Some x, hs ->
        match x with
        | Handler (xvar, fid, event, args) -> 
            (*Printf.printf "\nConsuming handler %s of event %s from hq!\n" (Val.str fid) (Events.str Val.str event);*)
            List.map (fun conf -> (conf, ehs, hs, n)) (Interpreter.continue_with_h conf xvar fid args) 
        
        | Conf conf' -> 
            let merged_conf = Interpreter.continue_with_conf conf conf' in
            [(merged_conf, ehs, hs, n)] 
        
        | CondConf (conf_info, pred, vs) -> 
            (* Printf.printf "I am checking if a condconf can continue its work\n"; *)
            let pred_b = 
              match Interpreter.run_proc conf pred vs with 
                | Some (v, _) ->
                    (match Val.to_literal v with 
                      | Some (Bool b) -> b
                      | _ -> raise (Failure "Await expects bool as result"))
                | None -> raise (Failure "pred condition failed!") in 
            if pred_b then (
              (* Printf.printf "It can continue!!!\n"; *)
              let merged_conf = Interpreter.continue_with_conf_info conf conf_info in 
              [(merged_conf, ehs, hs, n)]
            ) else (
               (* Printf.printf "It cannot continue!!\n"; *)
               let hq' = hs @ [ (CondConf (conf_info, pred, vs)) ] in 
               [ (conf, ehs, hq', n) ]
            )

  let handlers_str handlers = (String.concat " " (List.map (fun (fid, _) -> Printf.sprintf "\n\t\t\t Fid: %s" (Val.str fid)) handlers))
  
  let hq_elem_string (x: hq_element) : string = 
    let args_string args = (String.concat ", Args--: \n" (List.map (fun (arg) -> Printf.sprintf "Arg: %s" (Val.str arg)) args)) in
    match x with
    | Conf (c, _) -> Interpreter.string_of_cconf c
    | CondConf _ -> ""
    | Handler (_, fid, event, args) -> Printf.sprintf "\t Fid: %s, Event: %s, Args: %s \n" (Val.str fid) (Events.str Val.str event) (args_string args)
  
  let hq_string (hq: handler_queue_t) : string = (String.concat "\n" (List.map hq_elem_string hq))

  let state_str (state : state_t) : string =
    let (_, ehs, hq, _) = state in
    (*"\n--JSIL Conf--" ^ Interpreter.print_cconf econf ^*)
    "\n--Event Handlers--" ^ (SymbMap.str ehs (Events.str Val.str) handlers_str) ^ "\n--Handlers Queue--\n" ^ hq_string hq ^ "\n"
  
  let string_of_result (rets: result_t list) : string =
    String.concat "Event Semantics Result: \n" (List.map 
      (fun ret -> 
        let (lret, ehs, hq) = ret in
          Interpreter.string_of_result [lret] ^ 
          "\n--Event Handlers--" ^ (SymbMap.str ehs (Events.str Val.str) handlers_str) ^
          "\n--Handlers Queue--\n" ^ hq_string hq ^ "\n"
      ) rets) 
    
  let print_state (state : state_t) : unit = 
    L.log L.Normal (lazy (Printf.sprintf
        "\n-------------------EVENT CONFIGURATION------------------------\n%s------------------------------------------------------\n" (state_str state)))
  
  let dispatch 
      (ev_name             : event_t) 
      (state               : state_t) 
      (potential_listeners : ((fid_t * Val.t list) list * Formula.t) list) 
      (xvar                : Var.t)
      (argsv               : Val.t list)
      (sync                : bool) : state_t list =
    L.log L.Normal (lazy (Printf.sprintf "Dispatching event %s" (Events.str Val.str ev_name)));
    let (conf, ehs, hq, n) = state in
    let (cconf, prog) = conf in
    (* Configurations in which a listener applies *)
    let listener_confs = List.map (fun (hdlrs, f) -> 
      Interpreter.assume (Interpreter.copy_conf cconf) [ f ], hdlrs
    ) potential_listeners in 
    (* Configuration where no listener applies *)
    let no_listener_formulae = List.map (fun (_, f) -> Formula.Not f) potential_listeners in 
    let no_listener_conf = (Interpreter.assume cconf no_listener_formulae, []) in 
    (* All applicable configurations *)
    let confs = List.filter (fun (x, _) -> x <> None) (listener_confs @ [ no_listener_conf ]) in 
    let confs = List.map (fun (x, hdlrs) -> Option.get x, hdlrs) confs in 
    (* Dispatch *)
    List.fold_left
      (fun confs_so_far (new_conf, hdlrs) ->
        (match hdlrs with
          (* No handlers *)
          | [] -> confs_so_far @ [ (new_conf, prog), ehs, hq, n+1 ]
          (* At least one handler *)
          | (fid_0, args0) :: next_handlers -> 
            L.log L.Normal (lazy (Printf.sprintf "Found handler %s" (Val.str fid_0)));
            if (sync) then (
              let new_hq = (List.map (fun (fid, args') -> Scheduler.Handler (xvar, fid, ev_name, argsv @ args')) next_handlers) @ [Scheduler.Conf (new_conf, prog)] @ hq in
              let new_confs = Interpreter.continue_with_h (new_conf, prog) xvar fid_0 (argsv @ args0) in 
                  confs_so_far @ (List.map (fun new_conf -> new_conf, ehs, new_hq, n+1) new_confs)
            ) else (
              let new_hq = hq @ (List.map (fun (fid, args') -> Scheduler.Handler (xvar, fid, ev_name, argsv @ args')) hdlrs) in
                confs_so_far @ [((new_conf, prog), ehs, new_hq, n+1) ]
            )
          )
      ) [] confs
    
  let process_event_label (conf': Interpreter.econf_t)(label : event_label_t) (state: state_t) : state_t list =
    let (conf, ehs, hq, n) = state in 
    let (cconf, prog) = conf in

    match label with
    | SyncDispatch (xvar, event_type, event, args) -> 
        (* TODO: check how events will be created! *)
        let event = Events.create Val.to_literal (create_event_id hq) event_type event in
        (** Synchronous event dispatch*)           
        let listeners = SymbMap.find ehs event (Events.is_concrete Val.to_literal) (Events.to_expr Val.to_expr) in 
        dispatch event (conf', ehs, hq, n) listeners xvar args true 

    | AsyncDispatch (xvar, event_type, event, args) ->
        let event = Events.create Val.to_literal (create_event_id hq) event_type event in
        (** Asynchronous event dispatch*)
        let listeners = SymbMap.find ehs event (Events.is_concrete Val.to_literal) (Events.to_expr Val.to_expr) in 
        dispatch event (conf', ehs, hq, n) listeners xvar args false

    | AddHandler (event_type, event, handler, args) ->
        let event = Events.create Val.to_literal (create_event_id hq) event_type event in
        (** Add Event Handler *)
        let states = add_event_handler state event handler args in 
        List.map 
          (fun (conf, ehs, hq, n) -> 
            conf', ehs, hq, n
          ) states

    | RemoveHandler (event_type, event, handler) ->
        (** Remove Event Handler *)
        let event = Events.create Val.to_literal (create_event_id hq) event_type event in
        let states = remove_event_handler state event handler in
        List.map 
          (fun (conf, ehs, hq, n) -> 
            conf', ehs, hq, n
          ) states
    
    | Await (conf, conf_info, (pred, args)) ->  
        (* Await *)
        let hq' = hq @ [ (CondConf (conf_info, pred, args)) ] in
          [ (conf, prog), ehs, hq', n ]
      
    | Schedule (xvar, fid, args, time) -> 
        let (conf, ehs, hq, n) = state in
        let (cconf, prog) = conf' in
        let gen_event = GeneralEvent (Val.from_literal (String EventsConstants.schedule_event)) in
        let event, cconf = match time with
        | Some time -> 
          (*Printf.printf "\nFound schedule! time: %s" (Val.str time); *)
          (match Val.to_literal time with
          | Some (Num time) -> 
          (*Printf.printf "\nAdding timing event with time %f\n" time;*)
            let eid = create_event_id hq in
            TimingEvent (eid, time), Interpreter.set_var xvar (Val.from_literal (Num (float_of_int eid))) cconf
          | _ -> gen_event, cconf)
        | None -> gen_event, cconf in
        (* Dispatch *)
        List.fold_left
          (fun confs_so_far (new_conf, hdlrs) ->
            (match hdlrs with
              (* No handlers *)
              | [] -> confs_so_far @ [ (new_conf, prog), ehs, hq, n ]
              (* At least one handler *)
              | _ -> 
                let new_hq = hq @ (List.map (fun fid -> Scheduler.Handler (xvar, fid, event, args)) hdlrs) in
                    confs_so_far @ [((new_conf, prog), ehs, new_hq, n)]
              )
          ) [] [ cconf, [ fid ] ]
      
      | Unschedule (eid) -> 
        let (conf, ehs, hq, n) = state in
        (match Val.to_literal eid with
        | Some (Num eid) -> 
          let eid = int_of_float eid in
          let hq' = List.filter 
          (fun hdlr ->
            match hdlr with
            | Scheduler.Handler (_, _, TimingEvent (id, t), _) ->
              eid <> id
            | _ -> true 
          ) hq in
          [conf', ehs, hq', n]
        | _ -> [conf', ehs, hq, n])
        

      | _ -> [state]

  let process_label (conflab : (Interpreter.econf_t * event_label_t option)) (state: state_t) : (state_t * event_label_t option) list =
    let (conf', lab) = conflab in
    let (conf, ehs, hq, n) = state in 
    let (cconf', _) = conf' in 
    
    let lab' = 
      match lab with 
        | Some lab -> Some lab
        | None ->  Interpreter.synthetic_lab cconf' in 
    match lab' with 
        | None -> [ (conf', ehs, hq, n), None ]
        | Some MLabel other_label -> [ (conf', ehs, hq, n), Some (MLabel other_label) ]
        | Some label -> List.map (fun r -> r, None) (process_event_label conf' label state)
         

  let print_jsil_line_numbers (prog : UP.prog) : unit =
    let file_numbers_name = prog.prog.filename ^ "_raw_coverage.txt" in
      let out = open_out_gen [Open_wronly; Open_append; Open_creat; Open_text] 0o666 file_numbers_name in
        Hashtbl.iter (fun (proc_name, i) _ -> output_string out ("\""^proc_name^"\"" ^ " " ^ (string_of_int i) ^ "\n")) lines_executed;
        close_out out

  let make_step (state : state_t) (ext_intercept : ((vt -> (vt list) option) -> (vt -> Literal.t option) -> (Literal.t -> vt) -> string -> string -> vt list -> message_label_t option) option) : (state_t * event_label_t option) list * state_t option = 
    let (conf : Interpreter.econf_t), ehs, hq, _ = state in
    (*if (Interpreter.printing_allowed cconf) then 
      print_state state;*)
    if (Interpreter.final conf) then (
      L.log L.Normal (lazy (Printf.sprintf "\nConfiguration is final!"));
      let new_states = List.map (fun s -> s, None) (exec_handler state) in
      match new_states with
      | [] -> [], Some state
      | new_states -> new_states, None
    ) else (
      (** Conf is NOT final *)
      let rets = Interpreter.make_step lines_executed conf (Some (EventInterceptor.intercept ext_intercept)) in 
      List.concat (List.map (fun ret -> process_label ret state) rets), None
    )

  let rec make_steps (states: state_t list) : state_t list = 
    match states with
    | [] -> []
    | state :: sts ->
      (** We ignore the labels here, as the top-level semantics interacts via make_step *)
      let (states, fconf) = make_step state None in
      let (states, _) = List.split states in 
      (match states, fconf with 
      | [], Some fconf -> [fconf]
      | st :: rest, _ when final st -> st :: (make_steps sts)
      | _ -> make_steps (states @ sts)
      )

  let create_initial_state (prog: UP.prog) : state_t = 
    let initial_conf = (Interpreter.create_initial_conf prog None, prog) in
    initial_conf, SymbMap.init (), [], 0

  let econf_to_result (state: state_t) : result_t =
    let (econf, eh, hq, _) = state in let (conf, _) = econf in (Interpreter.conf_to_result conf, eh, hq)

  let evaluate_prog (prog: UP.prog) : result_t list =
    let initial_state = create_initial_state prog in
    let states = make_steps [initial_state] in
    if (!jsil_line_numbers) then print_jsil_line_numbers prog;
    List.map econf_to_result states

  let new_conf (url: string) (setup_fid: string) (args: vt list) (state: state_t) : state_t = 
    let (econf, _, _, _) = state in
    let econf' = Interpreter.new_conf url setup_fid args econf in
    econf', SymbMap.init (), [], 0

  let restart_conf (setup_fid: string) (args: vt list) (state: state_t) : state_t =
    let (econf, ehs, hq, n) = state in
    let econf' = Interpreter.add_setup_proc setup_fid args econf in
    econf', ehs, hq, n

  let set_var (xvar: Var.t) (v: vt) (state: state_t) : state_t = 
    let ((c, prog), h, q, n) = state in
    ((Interpreter.set_var xvar v c, prog), h, q, n)

  (* Environment event dispatch. Adds handlers at the back of the continuation queue *) 
  let fire_event (event: event_t) (args: vt list) (state: state_t) (sync: bool) : state_t list =
    let (c, ehs, hq, _) = state in 
    let listeners = SymbMap.find ehs event (Events.is_concrete Val.to_literal) (Events.to_expr Val.to_expr) in 
    (*if((List.length listeners) > 0) then
    (
      let fidsargs, f = List.hd listeners in
      Printf.printf "Listener: %s" (String.concat ", " (List.map (fun (fid, _) -> Val.str fid) fidsargs)); 
    );*)
    (* How to obtain xvar? The ideal thing to do would be allow calls without ret vars... *) 
    dispatch event state listeners "" args sync

  let fresh_lvar (x: string) (v: string) (state: state_t) (vart: Type.t) : state_t * vt =
    let ((conf, prog), ehs, hq, n) = state in
    let conf', v = Interpreter.fresh_lvar x v conf vart in
    ((conf', prog), ehs, hq, n), v

  let valid_result (rets: result_t list) : bool =
    let lrets = List.map (fun (lret, _, _) -> lret) rets in
    Interpreter.valid_result lrets

  let from_esem_result_to_lsem_result (rets: result_t list) : Interpreter.result_t list =
    List.map (fun (lret, _, _) -> lret) rets
     

  let add_spec_var (x:string list) (state: state_t) : state_t =
    let ((conf, prog), ehs, hq, n) = state in
    ((Interpreter.add_spec_var x conf), prog), ehs, hq, n
  
  let assume_type (x: string) (t: Type.t) (state: state_t) : state_t =
    let ((conf, prog), ehs, hq, n) = state in
    ((Interpreter.assume_type x t conf), prog), ehs, hq, n

  let assert_formula (f:Formula.t) (state: state_t) : state_t list =
    let (conf, prog), ehs, hq, n = state in
    let confs = Interpreter.assert_formula_from_conf f conf in
    List.map (fun c -> (c, prog), ehs, hq, n) confs

  let is_awaiting (state: state_t) : bool =
    let (conf, _), _, hq, _ = state in
    Interpreter.is_conf_finish conf && 
    List.length hq > 0 &&
    (List.for_all (
      fun hq_elem -> match hq_elem with
      | Scheduler.CondConf _ -> true
      | _ -> false
    ) hq)

end 