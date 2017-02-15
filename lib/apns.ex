defmodule APNS do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    pool_options = [
     name: {:local, :apns_pool},
     worker_module: APNS.PushWorker,
     size: 5,
     max_overflow: 10
   ]
    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Apns.Worker.start_link(arg1, arg2, arg3)
      :poolboy.child_spec(:apns_pool, pool_options, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: APNS.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def push(token, notification) do
    :poolboy.transaction(:apns_pool, fn(worker)->
        APNS.PushWorker.push(worker, token, notification)
      end)
  end

end
