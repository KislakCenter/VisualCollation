import React from 'react';
import Dialog from 'material-ui/Dialog';
import FlatButton from 'material-ui/FlatButton';
import fileDownload from 'js-file-download';
import copy from 'copy-to-clipboard';
import IconCopy from 'material-ui/svg-icons/content/content-copy';
import IconDownload from 'material-ui/svg-icons/file/file-download';
import IconButton from 'material-ui/IconButton';
import JSZip from 'jszip';
import saveAs from 'file-saver';

/** Dialog to export collation to JSON, XML or PNG */
const Export = props => {
    const filename = props.projectTitle.replace(/\s/g, '_');
    const actions = [
        <FlatButton
            label={'Download ' + props.exportedType}
            icon={<IconDownload/>}
            style={
                props.exportedImages
                    ? {marginRight: 10}
                    : {display: 'none'}
            }
            onClick={() => {
                downloadZip();
            }}
        />,
        <FlatButton
            label={"Download " + props.exportedType}
            icon={<IconDownload />}
            style={props.exportedType==="xml"?{marginRight:10}:{display:"none"}}
            onClick={()=>fileDownload(props.exportedData, `${filename}.${props.exportedType}`)}
        />,
        <FlatButton
            label={'Download ' + props.exportedType}
            icon={<IconDownload/>}
            style={
                props.exportedImages ||
                props.exportedType === 'xml' ||
                props.exportedType === 'share'
                    ? {display: 'none'}
                    : {marginRight: 10}
            }
            onClick={() =>
                downloadZip()
            }
        />,
        <FlatButton
            label="Close"
            primary={true}
            onClick={() => props.handleExportToggle(false)}
            keyboardFocused
        />,
    ];

    const downloadZip = () => {
        console.log(props.exportedImages)
        fetch(props.exportedImages)
            .then(function (response) {
                if (response.status === 200 || response.status === 0) {
                    return Promise.resolve(response.blob());
                } else {
                    return Promise.reject(new Error(response.statusText));
                }
            })
            .then(JSZip.loadAsync)
            .then(function (zip) {
                zip.generateAsync({type: 'blob'}).then(
                    function (blob) {
                        saveAs(blob, `${props.projectID}_${props.exportedType}.zip`);
                    },
                    function (err) {
                        console.log('error saving zip file!');
                    }
                );
            });
    };

    const exportedData =
        props.exportedType !== 'png' ? (
            <div
                style={{maxHeight: 500, overflow: 'scroll', background: '#f5f5f5'}}
            >
                <IconButton
                    style={{position: 'fixed', right: '40px'}}
                    tooltip="Copy to clipboard"
                    onClick={() => {
                        copy(
                            props.exportedType === 'share'
                                ? window.location.href + '/viewOnly'
                                : props.exportedData
                        );
                        props.showCopyToClipboardNotification();
                    }}
                >
                    <IconCopy/>
                </IconButton>

                {/* {props.exportedType === 'share'
          ? window.location.href + '/viewOnly'
          : props.exportedData} */}
                {props.exportedType === 'svg' ? (
                    <div>
                        {Array.from(props.exportedData)
                            .map((value, index) => {
                                return (
                                    <img
                                        alt={'Quire SVG'}
                                        key={index}
                                        src={`data:image/svg+xml;utf8,${encodeURIComponent(value)}`}
                                    ></img>
                                );
                            })}
                    </div>
                ) : (
                    <pre>{props.exportedData}</pre>
                )}
            </div>
        ) : (
            <div>
                Please download your PNGs below.

                <div style={{width: 1, height: 1, overflow: 'hidden'}}>
                    <canvas id="exportCanvas" width="1" height="1"/>
                </div>
            </div>
        );
    return (
        <Dialog
            title={props.label}
            actions={actions}
            modal={false}
            open={props.exportOpen}
            onRequestClose={() => props.handleExportToggle(false)}
            contentStyle={{maxWidth: 1000}}
        >
            {props.label === 'XML' ? (
                <p>
                    <strong>Note:</strong> custom folio numbers and page numbers will be
                    lost when exporting to XML format. If you wish to preserve all
                    collation data, please choose JSON export.
                </p>
            ) : (
                ''
            )}
            {props.label === 'Share this project' ? (
                <p>The URL below shows the view-only mode of your project.</p>
            ) : (
                ''
            )}
            {exportedData}
        </Dialog>
    );
};

export default Export;
