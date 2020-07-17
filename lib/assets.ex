defmodule Assets do
  use GenServer

  @moduledoc """
  Handles an external (Webpack) pipeline.

  Runs the pipeline, then loads the manifest it produces into a GenServer
  in order to provide asset name mapping.
  """

  def init(args) do
    {:ok, args}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: :assets)
  end

  def build() do
    System.cmd("yarn", ["run", "webpack"]) |> handle_build_result()
  end

  defp handle_build_result({_output, 0}) do
    manifest = "build/manifest.json"
    |> File.read!
    |> Jason.decode!
    |> Enum.into(
      %{},
      fn
        {"/" <> k, "/" <> v} -> {"/" <> k, "/" <> v}
        {"/" <> k,        v} -> {"/" <> k, "/" <> v}
        {       k, "/" <> v} -> {"/" <> k, "/" <> v}
        {       k,        v} -> {"/" <> k, "/" <> v}
      end
    )
    GenServer.call(:assets, {:put, manifest})
    {:ok}
  end
  defp handle_build_result({output, _exit_status}) do
    {:error, "External webpack pipeline failed to build\n\n#{output}"}
  end

  def manifest do
    GenServer.call(:assets, {:manifest})
  end

  def path("/" <> name) do
    GenServer.call(:assets, {:path, "/" <> name})
  end
  def path(name) do
    GenServer.call(:assets, {:path, "/" <> name})
  end

  def path!(name) do
    {:ok, path} = path(name)
    path
  end

  def handle_call({:put, state}, _from, _state) do
    {:reply, {:ok}, state}
  end
  def handle_call({:manifest}, _from, state) do
    {:reply, {:ok, state}, state}
  end
  def handle_call({:path, name}, _from, state) do
    if Map.has_key?(state, name) do
      path = state[name]
      {:reply, {:ok, path}, state}
    else
      {:reply, {:error, "'#{name}' not found in manifest"}, state}
    end
  end
end
