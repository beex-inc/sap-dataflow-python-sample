import logging
from contextlib import contextmanager
import apache_beam as beam
from apache_beam.options.pipeline_options import (
    PipelineOptions,
    SetupOptions,
    StandardOptions,
    GoogleCloudOptions,
    WorkerOptions,
)


class SapLoadJobOptions(PipelineOptions):
    @classmethod
    def _add_argparse_args(cls, parser) -> None:
        parser.add_argument("--job-project", default=None, help="Job Project")
        parser.add_argument("--job-name", default=None, help="Job Nmae")
        parser.add_argument("--base-bucket", default=None, help="GCP Base Bucket")
        parser.add_argument("--sap-ashost", default=None, help="SAP AS host name or IP")
        parser.add_argument("--sap-user", default=None, help="SAP user")
        parser.add_argument("--sap-passwd", default=None, help="SAP password")
        parser.add_argument("--sap-sysnr", default=None, help="SAP System Number")
        parser.add_argument("--sap-client", default=None, help="SAP Client Number")
        parser.add_argument("--sap-lang", default=None, help="SAP Lang")
        parser.add_argument("--bq-dataset", default=None, help="Dest BigQuery Dataset")
        parser.add_argument("--bq-table", default=None, help="Dest BigQuery Table")


class SapCompanyCodeDoFn(beam.DoFn):
    def __init__(self, user, passwd, ashost, sysnr, client, lang):
        self.user = user
        self.passwd = passwd
        self.ashost = ashost
        self.client = client
        self.sysnr = sysnr
        self.lang = lang

    @contextmanager
    def _open_connection(self):
        from pyrfc import Connection

        conn = Connection(
            user=self.user,
            passwd=self.passwd,
            ashost=self.ashost,
            sysnr=self.sysnr,
            client=self.client,
            lang=self.lang,
        )
        try:
            yield conn
        finally:
            if conn != None:
                conn.close()

    def process(self, element):
        with self._open_connection() as conn:
            res = conn.call("BAPI_COMPANYCODE_GETLIST")
            for r in res["COMPANYCODE_LIST"]:
                yield r


def main():
    options = SapLoadJobOptions()
    options.view_as(
        WorkerOptions
    ).sdk_container_image = f"gcr.io/{options.job_project}/{options.job_name}-worker"
    gcp_options = options.view_as(GoogleCloudOptions)
    gcp_options.staging_location = f"gs://{options.base_bucket}/dataflow/staging"
    gcp_options.temp_location = f"gs://{options.base_bucket}/dataflow/temp"
    setup_options = options.view_as(SetupOptions)
    setup_options.save_main_session = True
    options.view_as(StandardOptions).runner = "DataflowRunner"

    with beam.Pipeline(options=options) as p:
        logging.warn(options)
        (
            p
            | "dummy" >> beam.Create([None])
            | "Read SAP CompanyCode via BAPI"
            >> beam.ParDo(
                SapCompanyCodeDoFn(
                    user=options.sap_user,
                    passwd=options.sap_passwd,
                    ashost=options.sap_ashost,
                    sysnr=options.sap_sysnr,
                    client=options.sap_client,
                    lang=options.sap_lang,
                )
            )
            # | "logging" >> beam.Map(lambda x: logging.warn(x))
            | "Write to BQ"
            >> beam.io.WriteToBigQuery(
                project=options.job_project,
                dataset=options.bq_dataset,
                table=options.bq_table,
                schema={
                    "fields": [
                        {"name": "COMP_CODE", "type": "STRING"},
                        {"name": "COMP_NAME", "type": "STRING"},
                    ]
                },
                create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
                write_disposition=beam.io.BigQueryDisposition.WRITE_TRUNCATE,
            )
        )
        res = p.run()
        res.wait_until_finish()


if __name__ == "__main__":
    logging.getLogger().setLevel(logging.INFO)
    main()
