FROM gcr.io/dataflow-templates-base/python3-template-launcher-base

ARG WORKDIR=/dataflow/template
ARG BEAM_VERSION=2.31.0
RUN mkdir -p ${WORKDIR}
WORKDIR ${WORKDIR}


COPY main.py ${WORKDIR}/main.py
COPY setup.py ${WORKDIR}/setup.py
COPY spec/python_command_spec.json ${WORKDIR}/python_command_spec.json

ENV FLEX_TEMPLATE_PYTHON_PY_FILE="${WORKDIR}/main.py"
ENV FLEX_TEMPLATE_PYTHON_SETUP_FILE="${WORKDIR}/setup.py"
ENV DATAFLOW_PYTHON_COMMAND_SPEC="${WORKDIR}/python_command_spec.json"


RUN pip install --no-cache-dir --upgrade pip setuptools wheel 
RUN pip install --no-cache-dir apache-beam[gcp]==${BEAM_VERSION}
