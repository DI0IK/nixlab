{ config, pkgs, ... }:

{
  services.searx = {
    enable = true;
    redisCreateLocally = false;
    environmentFile = config.sops.templates."searxng.env".path;

    settings = {
      server = {
        secret_key = "$SEARX_SECRET_KEY";
        bind_address = "127.0.0.1";
        port = 8888;
        base_url = "https://search.dominikstahl.dev/";
        image_proxy = true;
      };

      valkey = {
        url = "redis://127.0.0.1:6379/4";
      };

      ui = {
        default_theme = "simple";
        infinite_scroll = true;
        query_in_title = true;
      };

      search = {
        safe_search = 0;
        autocomplete = "duckduckgo";
        favicon_resolver = "duckduckgo";
        formats = [
          "html"
          "csv"
          "json"
          "rss"
        ];
      };

      hostnames = {
        replace = {
          "(.*\\.)?reddit\\.com$" = "redlib.dominikstahl.dev";
        };
      };

      engines = [
        # Self-hosted Forgejo Git search
        {
          name = "forgejo";
          engine = "gitea";
          base_url = "https://git.dominikstahl.dev";
          shortcut = "fj";
          categories = [
            "it"
            "repos"
          ];
          disabled = false;
        }

        # Self-hosted Photon geocoding (OpenStreetMap)
        {
          name = "photon";
          engine = "photon";
          base_url = "http://127.0.0.1:2322/";
          categories = [ "map" ];
          disabled = false;
        }

        # Self-hosted Lemmy instance search
        {
          name = "lemmy";
          engine = "lemmy";
          base_url = "https://lemmy.dominikstahl.dev";
          shortcut = "lm";
          categories = [ "social" ];
          disabled = false;
        }

        # Self-hosted Kiwix ZIM search (German collection / Wikipedia)
        {
          name = "kiwix";
          engine = "xpath";
          search_url = "https://kiwix.dominikstahl.dev/search?books.name=wikipedia_de_all_maxi_2026-01&books.name=kochwiki.org_de_all_maxi_2026-07&books.name=wiktionary_de_all_nopic_2026-07&books.name=wikivoyage_de_all_maxi_2026-07&books.name=ifixit_de_all_2026-03&books.name=gutenberg_de_all_2026-01&pattern={query}&start={pageno}&pageLength=25";
          results_xpath = "//div[@class=\"results\"]/ul/li";
          url_xpath = "./a/@href";
          title_xpath = "./a";
          content_xpath = "./cite";
          shortcut = "kx";
          categories = [ "general" ];
          disabled = false;
          paging = true;
          page_size = 25;
          first_page_num = 0;
          no_result_for_http_status = [
            400
            404
          ];
        }

        # Self-hosted Kiwix ZIM search (English Wikipedia / StackExchange / ArchWiki)
        {
          name = "kiwix_en";
          engine = "xpath";
          search_url = "https://kiwix.dominikstahl.dev/search?books.name=wikipedia_en_all_maxi_2026-08&books.name=archlinux_en_all_maxi_2026-07&books.name=devdocs_en_nix_2026-10&books.name=stackoverflow.com_en_all_2026-07&books.name=superuser.com_en_all_2026-08&pattern={query}&start={pageno}&pageLength=25";
          results_xpath = "//div[@class=\"results\"]/ul/li";
          url_xpath = "./a/@href";
          title_xpath = "./a";
          content_xpath = "./cite";
          shortcut = "kxe";
          categories = [ "general" ];
          disabled = false;
          paging = true;
          page_size = 25;
          first_page_num = 0;
          no_result_for_http_status = [
            400
            404
          ];
        }
      ];
    };
  };

  # Ensure Valkey caching service is up before SearXNG starts
  systemd.services.searx = {
    after = [ "redis-default.service" ];
    wants = [ "redis-default.service" ];
  };

  # Impermanence persistence for SearXNG
  environment.persistence."/persist" = {
    directories = [
      "/var/lib/searx"
    ];
  };
}
