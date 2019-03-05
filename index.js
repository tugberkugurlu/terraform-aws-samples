// https://docs.aws.amazon.com/lambda/latest/dg/nodejs-prog-model-handler.html
// https://docs.aws.amazon.com/lambda/latest/dg/with-sqs-create-package.html#with-sqs-example-deployment-pkg-nodejs
exports.myHandler = async function(event, context) {
    event.Records.forEach(record => {
        const { body } = record;
        console.log(body);
    });
    return {};
}