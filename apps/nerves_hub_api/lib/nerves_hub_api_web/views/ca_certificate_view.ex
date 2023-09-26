defmodule NervesHubAPIWeb.CACertificateView do
  use NervesHubAPIWeb, :view

  alias NervesHubAPIWeb.CACertificateView
  alias NervesHubWebCore.Devices.CACertificate

  def render("index.json", %{ca_certificates: ca_certificates}) do
    %{data: render_many(ca_certificates, CACertificateView, "ca_certificate.json")}
  end

  def render("show.json", %{ca_certificate: ca_certificate}) do
    %{data: render_one(ca_certificate, CACertificateView, "ca_certificate.json")}
  end

  def render("ca_certificate.json", %{ca_certificate: ca_certificate}) do
    %{
      serial: ca_certificate.serial,
      not_before: ca_certificate.not_before,
      not_after: ca_certificate.not_after,
      description: ca_certificate.description,
      jitp:
        case ca_certificate.jitp do
          %CACertificate.JITP{product: p, description: d, tags: t} ->
            %{
              product: p && p.name,
              description: d,
              tags: t
            }

          _ ->
            %{}
        end
    }
  end

  # TODO: Remove when legacy clients have been upgraded
  def render("jitp.json", %{ca_certificate: ca_certificate}) do
    %{
      data: %{
        product: ca_certificate.jitp.product.name,
        description: ca_certificate.jitp.description,
        tags: ca_certificate.jitp.tags
      }
    }
  end
end
