defmodule Pleroma.Search do
  alias Pleroma.User
  alias Pleroma.Workers.SearchIndexingWorker

  def add_to_index(%Pleroma.Activity{data: %{"actor" => actor}} = activity) do
    with %User{is_indexable: true} <- User.get_cached_by_ap_id(actor) do
      SearchIndexingWorker.enqueue("add_to_index", %{"activity" => activity.id})
    else
      _ -> :ok
    end
  end

  def remove_from_index(%Pleroma.Object{id: object_id}) do
    SearchIndexingWorker.enqueue("remove_from_index", %{"object" => object_id})
  end

  def search(query, options) do
    search_module = Pleroma.Config.get([Pleroma.Search, :module], Pleroma.Activity)

    search_module.search(options[:for_user], query, options)
  end
end
