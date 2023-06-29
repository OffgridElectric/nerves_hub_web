defmodule NervesHubAPIWeb.CACertificateControllerTest do
  alias NervesHubWebCore.Devices.CACertificate
  use NervesHubAPIWeb.ConnCase, async: true

  alias NervesHubWebCore.{Devices, Certificate}

  describe "index" do
    test "lists all ca certificates", %{conn: conn, org: org} do
      conn = get(conn, Routes.ca_certificate_path(conn, :index, org.name))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create ca certificate" do
    test "renders key when data is valid", %{conn: conn, org: org} do
      ca_key = X509.PrivateKey.new_ec(:secp256r1)
      ca_cert = X509.Certificate.self_signed(ca_key, "CN=#{org.name}", template: :root_ca)
      serial = X509.Certificate.serial(ca_cert) |> to_string
      ca_cert_pem = X509.Certificate.to_pem(ca_cert)
      description = "My ca"

      params = %{cert: Base.encode64(ca_cert_pem), description: description}

      conn = post(conn, Routes.ca_certificate_path(conn, :create, org.name), params)
      resp_data = json_response(conn, 201)["data"]
      assert %{"serial" => ^serial} = resp_data
      assert %{"description" => ^description} = resp_data
    end

    test "renders errors when data is invalid", %{conn: conn, org: org} do
      conn = post(conn, Routes.ca_certificate_path(conn, :create, org.name), cert: "")

      assert json_response(conn, 500)["errors"] != %{}
    end
  end

  describe "delete ca_certificate" do
    setup [:create_ca_certificate]

    test "deletes chosen ca_certificate", %{conn: conn, org: org, ca_certificate: ca_certificate} do
      conn =
        delete(conn, Routes.ca_certificate_path(conn, :delete, org.name, ca_certificate.serial))

      assert response(conn, 204)

      conn = get(conn, Routes.ca_certificate_path(conn, :show, org.name, ca_certificate.serial))

      assert response(conn, 404)
    end
  end

  describe "view ca_certificate" do
    setup [:create_ca_certificate_with_jitp]

    test "renders when given valid SKI", %{conn: conn, org: org, ca_certificate: ca_certificate} do
      ski16 = Base.encode16(ca_certificate.ski)

      conn = get(conn, Routes.ca_certificate_path(conn, :show, org.name, "/ski/#{ski16}"))

      resp_data = json_response(conn, 200)["data"]

      assert resp_data == %{
               "description" => ca_certificate.description,
               "jitp" => %{
                 "description" => ca_certificate.jitp.description,
                 "product" => ca_certificate.jitp.product.name,
                 "tags" => ca_certificate.jitp.tags
               },
               "not_after" => DateTime.to_iso8601(ca_certificate.not_after),
               "not_before" => DateTime.to_iso8601(ca_certificate.not_before),
               "serial" => ca_certificate.serial
             }
    end
  end

  defp create_ca_certificate(%{org: org}) do
    ca_key = X509.PrivateKey.new_ec(:secp256r1)
    ca = X509.Certificate.self_signed(ca_key, "CN=#{org.name}", template: :root_ca)
    {not_before, not_after} = Certificate.get_validity(ca)

    params = %{
      serial: Certificate.get_serial_number(ca),
      aki: Certificate.get_aki(ca),
      ski: Certificate.get_ski(ca),
      not_before: not_before,
      not_after: not_after,
      der: X509.Certificate.to_der(ca),
      description: "My CA"
    }

    {:ok, ca_certificate} = Devices.create_ca_certificate(org, params)
    {:ok, %{ca_certificate: ca_certificate}}
  end

  defp create_ca_certificate_with_jitp(%{org: org, product: product}) do
    {:ok, %{ca_certificate: ca_certificate}} = create_ca_certificate(%{org: org})

    # Add JITP profile to CA db cert
    jitp =
      %CACertificate.JITP{
        product_id: product.id,
        tags: ["hello", "jitp"],
        description: "jitp"
      }
      |> NervesHubWebCore.Repo.insert!()

    ca_certificate
    |> NervesHubWebCore.Repo.preload([:org, :jitp])
    |> Ecto.Changeset.change(%{jitp_id: jitp.id})
    |> NervesHubWebCore.Repo.update!()

    # refetch CACert with jitp
    {:ok, ca_certificate_with_jitp} = Devices.get_ca_certificate_by_ski(ca_certificate.ski)

    {:ok, %{ca_certificate: ca_certificate_with_jitp}}
  end
end
