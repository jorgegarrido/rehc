%% _____________________________________________________________________________
%%
%% Copyright (c) 2014 Jorge Garrido <zgbjgg@gmail.com>.
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions
%% are met:
%% 1. Redistributions of source code must retain the above copyright
%%    notice, this list of conditions and the following disclaimer.
%% 2. Redistributions in binary form must reproduce the above copyright
%%    notice, this list of conditions and the following disclaimer in the
%%    documentation and/or other materials provided with the distribution.
%% 3. Neither the name of copyright holders nor the names of its
%%    contributors may be used to endorse or promote products derived
%%    from this software without specific prior written permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%% TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
%% PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL COPYRIGHT HOLDERS OR CONTRIBUTORS
%% BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
%% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
%% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%% POSSIBILITY OF SUCH DAMAGE.
%%
%% _____________________________________________________________________________
%%
%% [ zgbjgg ]
%%
%% @author zgbjgg@gmail.com
%% @copyright 2013 Jorge Garrido
%% @doc Send email notifications
-module(rehc_mailer).
-vsn("1.0").
-include("rehc.hrl").
-export([send/3]).

%% @doc Send mail to notify about application state 
send(A, App, Reason) ->
    Host = rehc_utility:get_value(A, node),
    NodeIn = rehc_utility:make_node(Host, "rehc"),
    Nodes = rehc_cluster:get_nodes(),
    [ Ip ] = [ Ip || {Node, Ip} <- Nodes, Node == NodeIn ],
    Msg = ?MAIL(?DATE_LOG, App, Ip, Reason),
    [ os:cmd("echo -e \""++Msg++"\"| mail -s \"Rehc\" "++Email) ||
	Email <- emails() ].

%% @doc Get list of emails configured to receive notifications 
emails() ->
    {ok, RehcMail} = application:get_env(rehc, rehc_email), 
    rehc_utility:get_value(RehcMail, mail).
