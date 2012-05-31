%% ==============================================================================
%
% REHC CLUSTER	
%
% Copyright (c) 2012 Jorge Garrido <jorge.garrido@morelosoft.com>.
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions
% are met:
% 1. Redistributions of source code must retain the above copyright
%    notice, this list of conditions and the following disclaimer.
% 2. Redistributions in binary form must reproduce the above copyright
%    notice, this list of conditions and the following disclaimer in the
%    documentation and/or other materials provided with the distribution.
% 3. Neither the name of copyright holders nor the names of its
%    contributors may be used to endorse or promote products derived
%    from this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
% ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
% TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
% PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL COPYRIGHT HOLDERS OR CONTRIBUTORS
% BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%% ===============================================================================
-module(rehc_cluster).
-vsn("1.0").
-behaviour(gen_server).

%% API
-export([start_link/0, add_node/3, stop/0, request/4,
	 get_nodes/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {nodes=[]}).

%%%===================================================================
%%% API
%%%===================================================================

add_node(Host, Name, Ip) ->
    gen_server:call(?MODULE, {adding_node, Host, Name, Ip}).

get_nodes() ->
    gen_server:call(?MODULE, getting_nodes).

request(Host, M, F, A) ->
    MadeNode = rehc_utility:make_node(Host, "rehc"),
    gen_server:call(?MODULE, {requesting, MadeNode, M, F, A}).

stop() ->
    gen_server:call(?MODULE, stop).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    {ok, Config} = application:get_env(rehc, cluster),
    gen_server:start_link({local, ?SERVER}, ?MODULE, [Config], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initiates the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([Config]) ->
    process_flag(trap_exit, true),
    Nodes = [begin
  		 O="-setcookie "++proplists:get_value(cookie,Config),
  		 S=proplists:get_value(slave, Config),
  		 {ok, Node} = slave:start(Host, S, O),
  		 error_logger:info_msg("Started slave ~p at ~p", [Node,Ip]),
  		 {Node, Ip}
  	     end || {Host, Ip} <- proplists:get_value(servers,Config)],
    {ok, #state{nodes=Nodes}, 1000}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({adding_node, Host, Name, Ip}, _From, State=#state{nodes=N}) ->
    {ok, Config} = application:get_env(rehc, cluster),
    O = "-setcookie "++proplists:get_value(cookie,Config),
    {ok, Node} = slave:start(Host, Name, O),
    {NewState, Reply} =
	case net_adm:ping(Node) of
	    pong -> {State#state{nodes=[{Node,Ip}]++N}, {ok, connected}};
	    _    -> {State#state{nodes=[]++N}, {nok, could_not_connect}}
	end,
    {reply, Reply, NewState, 1000};
handle_call({requesting, Node, M, F, A}, _From, State)                   ->
    Reply = case rpc:call(Node, M, F, A) of
		{badrpc, X} -> {nok, X};
		Res         -> {ok, Res}
	    end,
    {reply, Reply, State, 1000};
handle_call(getting_nodes, _From, State=#state{nodes=N})                 ->
    {reply, N, State, 1000};
handle_call(stop, _From, State)                                          ->
    {stop, normal, ok, State, 1000}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(timeout, State=#state{nodes=N}) ->
    Connected=[X || {Node,_}=X <- N, net_adm:ping(Node) == pong],
    Restarted =
	[begin
	     {ok, Config} = application:get_env(rehc, cluster),
	     O = "-setcookie "++proplists:get_value(cookie,Config),
	     error_logger:error_msg("Node disconnected: ~p at ~p~n", [Node,Ip]),
	     {Host, Name} = rehc_utility:unmake_node(Node),
	     {ok, RestartedNode} = slave:start(Host,Name,O),
	     error_logger:info_msg("Restarted node ~p at ~p~n", [Node, Ip]),
	     {RestartedNode, Ip}
	 end || {Node, Ip}=X <- N, false==lists:member(X, Connected)],
    {noreply, State#state{nodes=Connected++Restarted}, 1000}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
